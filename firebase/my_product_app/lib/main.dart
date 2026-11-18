import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  ////// 1. set up Flutter's binding first so platform channels (Dart <-> Android) exist //////
  WidgetsFlutterBinding.ensureInitialized();

  ////// 2. start native Firebase through those channels, using this project's config //////
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ////// 3. build the UI last so Firestore is ready before the first query //////
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Autumn Product Manager',
      home: ProductPage(),
    ),
  );
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('products');
  late final _productStream = _products.snapshots();

  ////// controllers for the search box and the min/max price boxes //////
  final _search = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();

  ////// dispose the controllers I added so they don't leak //////
  @override
  void dispose() {
    _search.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  ////// Reset clears search + min + max and shows the full list again //////
  void _resetFilters() {
    setState(() {
      _search.clear();
      _min.clear();
      _max.clear();
    });
  }

  Future<void> _createOrUpdate([
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) =>
          ProductEditor(products: _products, document: document),
    );
  }

  Future<void> _deleteProduct(String id) async {
    ////// ask first so nobody deletes by accident //////
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      ////// delete the exact document by its ID (not name, not list index) //////
      await _products.doc(id).delete();

      ////// only show success AFTER the delete actually finished //////
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } on FirebaseException catch (e) {
      ////// show the real failure instead of pretending it worked //////
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed (${e.code}). Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ////// read + check the price range inputs (empty = no limit) //////
    final minText = _min.text.trim();
    final maxText = _max.text.trim();
    final minValue = minText.isEmpty ? null : double.tryParse(minText);
    final maxValue = maxText.isEmpty ? null : double.tryParse(maxText);

    String? filterError;
    if (minText.isNotEmpty &&
        (minValue == null || !minValue.isFinite || minValue < 0)) {
      filterError = 'Min price must be a number of 0 or more (like 12.50).';
    } else if (maxText.isNotEmpty &&
        (maxValue == null || !maxValue.isFinite || maxValue < 0)) {
      filterError = 'Max price must be a number of 0 or more (like 12.50).';
    } else if (minValue != null && maxValue != null && minValue > maxValue) {
      filterError = 'Min price cannot be bigger than max price.';
    }

    ////// if the range is invalid, ignore it until the user fixes it //////
    final minPrice = filterError == null ? minValue : null;
    final maxPrice = filterError == null ? maxValue : null;

    ////// search policy: case-insensitive substring match on the name //////
    final query = _search.text.trim().toLowerCase();
    final filtersActive =
        query.isNotEmpty || minPrice != null || maxPrice != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Autumn Product Manager')),
      ////// Column so the search/filter bar sits above the list //////
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search by name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _min,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Min price',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _max,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Max price',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                ////// show why the price range is invalid //////
                if (filterError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      filterError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Products could not load. Check connection and permissions.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final documents = snapshot.data!.docs;
                if (documents.isEmpty) {
                  return const Center(
                    child: Text('No products yet. Add one to begin.'),
                  );
                }

                ////// filter in memory: name AND price range must both match //////
                final shown = documents.where((document) {
                  final data = document.data();
                  final name = data['name'];
                  final price = data['price'];
                  if (name is! String ||
                      name.trim().isEmpty ||
                      price is! num ||
                      !price.isFinite ||
                      price < 0) {
                    return !filtersActive;
                  }
                  if (!name.trim().toLowerCase().contains(query)) return false;
                  if (minPrice != null && price < minPrice) return false;
                  if (maxPrice != null && price > maxPrice) return false;
                  return true;
                }).toList();

                ////// products exist but none match the filters //////
                if (shown.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }

                return ListView.builder(
                  ////// use the filtered list instead of all documents //////
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final document = shown[index];
                    final data = document.data();
                    final name = data['name'];
                    final price = data['price'];
                    if (name is! String ||
                        name.trim().isEmpty ||
                        price is! num ||
                        !price.isFinite ||
                        price < 0) {
                      return ListTile(
                        title: Text(
                          'Invalid product ${document.id}: check name/price types.',
                        ),
                      );
                    }
                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(
                          '${price.toStringAsFixed(2)}\nID: ${document.id}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit product',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _createOrUpdate(document),
                            ),
                            IconButton(
                              tooltip: 'Delete product',
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteProduct(document.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create product',
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.products, this.document});

  final CollectionReference<Map<String, dynamic>> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.document?.data()['name'] as String? ?? '',
  );
  late final _price = TextEditingController(
    text: widget.document?.data()['price']?.toString() ?? '',
  );
  var _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final data = <String, Object>{
      'name': _name.text.trim(),
      'price': double.parse(_price.text.trim()),
    };
    try {
      final document = widget.document;
      if (document == null) {
        await widget.products.add(data);
      } else {
        await widget.products.doc(document.id).update(data);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      debugPrint('Product save failed (${error.code}): ${error.message}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Save failed (${error.code}). '
            'Check your connection and permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.document == null ? 'Create product' : 'Edit product',
                ),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || !amount.isFinite || amount < 0
                        ? 'Enter a finite price of zero or more'
                        : null;
                  },
                ),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saving)
                  const Text(
                    'Awaiting server acknowledgement. If offline, reconnect. '
                    'This editor stays open until the write succeeds or fails.',
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
