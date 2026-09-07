import 'package:flutter/cupertino.dart';

import '../controllers/task_controller.dart';
import '../models/task_category.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({required this.controller, super.key});
  final TaskController controller;

  Future<void> _edit(BuildContext context, [TaskCategory? category]) =>
      showCupertinoDialog<void>(
        context: context,
        builder: (_) =>
            _CategoryEditor(controller: controller, category: category),
      );

  Future<void> _delete(BuildContext context, TaskCategory category) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Kategorie löschen?'),
        content: Text(
          '„${category.name}“ wird gelöscht. Alle zugehörigen Aufgaben bleiben erhalten und werden „Ohne Kategorie“ zugeordnet.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteCategory(category.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Kategorien'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          key: const ValueKey('add-category'),
          onPressed: controller.isLoading ? null : () => _edit(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              children: [
                if (controller.storageError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(controller.storageError!),
                  ),
                if (controller.storageError != null)
                  CupertinoButton(
                    onPressed: controller.retrySave,
                    child: const Text('Erneut speichern'),
                  ),
                if (controller.categoryItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Noch keine Kategorien. Mit + eine Kategorie erstellen.',
                    ),
                  ),
                for (final category in controller.categoryItems)
                  CupertinoListTile(
                    leading: Icon(
                      category.iconData,
                      color: Color(category.color),
                    ),
                    title: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _edit(context, category),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      key: ValueKey('delete-category-${category.id}'),
                      onPressed: () => _delete(context, category),
                      child: const Icon(CupertinoIcons.delete),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.controller, this.category});
  final TaskController controller;
  final TaskCategory? category;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController name = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late int color = widget.category?.color ?? TaskCategory.colors.first;
  late String icon = widget.category?.icon ?? 'folder';
  String? error;
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.controller.saveCategory(
        id: widget.category?.id,
        name: name.text,
        color: color,
        icon: icon,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on TaskValidationException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(
      widget.category == null ? 'Neue Kategorie' : 'Kategorie bearbeiten',
    ),
    content: SizedBox(
      height: 300,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              key: const ValueKey('category-name'),
              controller: name,
              placeholder: 'Name',
            ),
            const SizedBox(height: 16),
            const Text('Farbe'),
            Wrap(
              children: [
                for (final value in TaskCategory.colors)
                  CupertinoButton(
                    key: ValueKey('color-$value'),
                    padding: const EdgeInsets.all(8),
                    onPressed: () => setState(() => color = value),
                    child: Icon(
                      color == value
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.circle_fill,
                      color: Color(value),
                    ),
                  ),
              ],
            ),
            const Text('Icon'),
            Wrap(
              children: [
                for (final entry in TaskCategory.icons.entries)
                  CupertinoButton(
                    key: ValueKey('icon-${entry.key}'),
                    padding: const EdgeInsets.all(8),
                    color: icon == entry.key
                        ? CupertinoColors.systemGrey5
                        : null,
                    onPressed: () => setState(() => icon = entry.key),
                    child: Semantics(
                      label: entry.key,
                      selected: icon == entry.key,
                      child: Icon(entry.value),
                    ),
                  ),
              ],
            ),
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
          ],
        ),
      ),
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      CupertinoDialogAction(
        key: const ValueKey('save-category'),
        onPressed: saving ? null : save,
        child: const Text('Speichern'),
      ),
    ],
  );
}
