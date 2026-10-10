import 'package:flutter/material.dart';
import '../database_help.dart';
import '../models/folder.dart';
import '../models/catalog_card.dart';

const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
const symbols = {'Hearts': '♥', 'Diamonds': '♦', 'Clubs': '♣', 'Spades': '♠'};

Future<bool> confirmDelete(BuildContext context, String kind, String name, int id) async =>
    await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete $kind?'),
      content: Text('Delete $kind "$name" (ID $id)?${kind == 'folder' ? ' Its cards will also be deleted.' : ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    )) ?? false;

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key, required this.helper});
  final DatabaseHelper helper;
  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Folder> folders = [];
  bool busy = false;
  String? error;
  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final result = await widget.helper.getFoldersWithCounts();
      if (mounted) setState(() => folders = result);
    } catch (e) { if (mounted) setState(() => error = 'Could not load folders: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> editFolder([Folder? folder]) async {
    if (busy) return;
    final controller = TextEditingController(text: folder?.name ?? '');
    final key = GlobalKey<FormState>();
    final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(folder == null ? 'Add folder' : 'Edit folder ID ${folder.id}'),
      content: Form(key: key, child: TextFormField(
        controller: controller, autofocus: true,
        decoration: const InputDecoration(labelText: 'Folder name'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Enter a folder name' : null,
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(ctx, controller.text.trim()); }, child: const Text('Save')),
      ],
    ));
    controller.dispose();
    if (!mounted || name == null) return;
    setState(() => busy = true);
    try {
      final result = folder == null ? await widget.helper.insertFolder(name) : await widget.helper.updateFolder(folder.id!, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(folder == null ? 'Added folder ID $result' : result == 1 ? 'Updated folder ID ${folder.id}' : 'Folder ID ${folder.id} not found')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Folder save failed: $e')));
    } finally { if (mounted) setState(() => busy = false); }
    await refresh();
  }

  Future<void> remove(Folder folder) async {
    if (busy || !await confirmDelete(context, 'folder', folder.name, folder.id!)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final count = await widget.helper.deleteFolder(folder.id!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count == 1 ? 'Deleted folder ID ${folder.id} and its cards' : 'Folder ID ${folder.id} not found')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'))); }
    finally { if (mounted) setState(() => busy = false); }
    await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Folders'), actions: [IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: busy ? null : () => editFolder(), icon: const Icon(Icons.add), label: const Text('Add folder')),
    body: busy && folders.isEmpty ? const Center(child: CircularProgressIndicator()) :
      ListView(children: [
        if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        if (folders.isEmpty && error == null) const ListTile(title: Text('No folders yet. Tap Add folder.')),
        for (final folder in folders) ListTile(
          title: Text(folder.name), subtitle: Text('ID ${folder.id} • ${folder.cardCount} card(s)'),
          onTap: busy ? null : () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => CardsScreen(helper: widget.helper, folder: folder))); if (mounted) await refresh(); },
          trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Edit folder', onPressed: busy ? null : () => editFolder(folder), icon: const Icon(Icons.edit)),
            IconButton(tooltip: 'Delete folder', onPressed: busy ? null : () => remove(folder), icon: const Icon(Icons.delete)),
          ]),
        ),
      ]),
  );
}

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key, required this.helper, required this.folder});
  final DatabaseHelper helper;
  final Folder folder;
  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CatalogCard> cards = [];
  bool busy = false;
  String? error;
  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final rows = await widget.helper.getCards(widget.folder.id!);
      if (mounted) setState(() => cards = rows);
    } catch (e) { if (mounted) setState(() => error = 'Could not load cards: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> editCard([CatalogCard? card]) async {
    if (busy) return;
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CardFormScreen(helper: widget.helper, card: card, defaultFolderId: widget.folder.id!)));
    if (mounted && result == true) await refresh();
  }

  Future<void> remove(CatalogCard card) async {
    if (busy || !await confirmDelete(context, 'card', card.title, card.id!)) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final count = await widget.helper.deleteCard(card.id!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count == 1 ? 'Deleted card ID ${card.id}' : 'Card ID ${card.id} not found')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'))); }
    finally { if (mounted) setState(() => busy = false); }
    await refresh();
  }

  Widget cardImage(CatalogCard card) {
    final ref = card.imageRef?.trim() ?? '';
    final placeholder = Center(child: Text(symbols[card.suit] ?? '?', style: const TextStyle(fontSize: 34)));
    if (ref.isEmpty) return SizedBox(width: 60, height: 60, child: placeholder);
    final uri = Uri.tryParse(ref);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty) {
      return SizedBox(width: 60, height: 60, child: Image.network(ref, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (_, child, progress) => progress == null ? child : placeholder));
    }
    if (ref.startsWith('assets/')) {
      return SizedBox(width: 60, height: 60, child: Image.asset(ref, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder));
    }
    return SizedBox(width: 60, height: 60, child: placeholder);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.folder.name} • ID ${widget.folder.id}'), actions: [IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: busy ? null : () => editCard(), icon: const Icon(Icons.add), label: const Text('Add card')),
    body: ListView(children: [
      if (error != null) ListTile(title: Text(error!)),
      if (cards.isEmpty && !busy && error == null) const ListTile(title: Text('This folder has no cards yet.')),
      for (final card in cards) ListTile(
        leading: cardImage(card),
        title: Text(card.title),
        subtitle: Text('ID ${card.id} • ${card.suit} • Folder ID ${card.folderId}\n${card.notes}'),
        isThreeLine: card.notes.isNotEmpty,
        trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: busy ? null : () => editCard(card), icon: const Icon(Icons.edit)),
          IconButton(onPressed: busy ? null : () => remove(card), icon: const Icon(Icons.delete)),
        ]),
      ),
    ]),
  );
}

class CardFormScreen extends StatefulWidget {
  const CardFormScreen({super.key, required this.helper, required this.defaultFolderId, this.card});
  final DatabaseHelper helper;
  final int defaultFolderId;
  final CatalogCard? card;
  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController notesController;
  late final TextEditingController imageController;
  late String suit;
  late int folderId;
  List<Folder> folders = [];
  bool busy = false;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.card?.title ?? '');
    notesController = TextEditingController(text: widget.card?.notes ?? '');
    imageController = TextEditingController(text: widget.card?.imageRef ?? '');
    suit = widget.card?.suit ?? suits.first;
    folderId = widget.card?.folderId ?? widget.defaultFolderId;
    loadFolders();
  }
  @override
  void dispose() { titleController.dispose(); notesController.dispose(); imageController.dispose(); super.dispose(); }
  Future<void> loadFolders() async {
    try {
      final result = await widget.helper.getFoldersWithCounts();
      if (mounted) setState(() { folders = result; loading = false; });
    } catch (e) { if (mounted) setState(() { error = '$e'; loading = false; }); }
  }
  Future<void> save() async {
    if (busy || loading || !formKey.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    try {
      if (!await widget.helper.folderExists(folderId)) throw StateError('Selected folder no longer exists');
      final card = CatalogCard(id: widget.card?.id, title: titleController.text.trim(),
        suit: suit, notes: notesController.text.trim(),
        imageRef: imageController.text.trim().isEmpty ? null : imageController.text.trim(),
        folderId: folderId);
      final result = widget.card == null ? await widget.helper.insertCard(card) : await widget.helper.updateCard(card);
      if (!mounted) return;
      if (widget.card != null && result == 0) throw StateError('Card ID ${widget.card!.id} no longer exists');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.card == null ? 'Added card ID $result' : 'Updated card ID ${widget.card!.id}')));
      Navigator.pop(context, true);
    } catch (e) { if (mounted) setState(() => error = 'Could not save card: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.card == null ? 'Add card' : 'Edit card ID ${widget.card!.id}')),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      Form(key: formKey, child: Column(children: [
        TextFormField(controller: titleController, enabled: !busy,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Title cannot be blank' : null),
        DropdownButtonFormField<String>(initialValue: suits.contains(suit) ? suit : suits.first,
          decoration: const InputDecoration(labelText: 'Suit'),
          items: suits.map((s) => DropdownMenuItem(value: s, child: Text('$s ${symbols[s]}'))).toList(),
          onChanged: busy ? null : (v) { if (v != null) setState(() => suit = v); }),
        DropdownButtonFormField<int>(initialValue: folders.any((f) => f.id == folderId) ? folderId : null,
          decoration: const InputDecoration(labelText: 'Folder'),
          items: folders.map((f) => DropdownMenuItem(value: f.id!, child: Text('${f.name} (ID ${f.id})'))).toList(),
          onChanged: busy ? null : (v) { if (v != null) setState(() => folderId = v); },
          validator: (v) => v == null ? 'Select a valid folder' : null),
        TextFormField(controller: notesController, enabled: !busy, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes (optional)')),
        TextFormField(controller: imageController, enabled: !busy,
          decoration: const InputDecoration(labelText: 'Image reference (optional)', hintText: 'https://... or assets/...')),
      ])),
      const SizedBox(height: 16),
      FilledButton(onPressed: busy || folders.isEmpty ? null : save, child: Text(busy ? 'Saving...' : 'Save card')),
      OutlinedButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
    ]),
  );
}
