import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/stok_master.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/alice_inspector_button.dart';

class BarkodTanimlaScreen extends StatefulWidget {
  const BarkodTanimlaScreen({super.key});

  @override
  State<BarkodTanimlaScreen> createState() => _BarkodTanimlaScreenState();
}

class _BarkodTanimlaScreenState extends State<BarkodTanimlaScreen> {
  List<StokMaster> _allItems = [];
  List<StokMaster> _filteredItems = [];
  bool _isLoading = false;
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_applyFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStoklar());
  }

  @override
  void dispose() {
    _filterController.removeListener(_applyFilter);
    _filterController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _filterController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(_allItems);
      } else {
        _filteredItems = _allItems
            .where((s) =>
                s.ad.toLowerCase().contains(q) ||
                s.genelKod.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _loadStoklar() async {
    final dbProvider =
        Provider.of<SelectedDatabaseProvider>(context, listen: false);
    final dbId = dbProvider.selectedDatabase?.id;
    if (dbId == null) return;
    final token = await StorageService.getToken();
    if (token == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getStokMasterAll(token, dbId);
      if (!mounted) return;
      setState(() {
        _allItems = response.value;
        _filteredItems = List.from(_allItems);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTap(StokMaster item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BarkodDialog(stok: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Tanımla'),
        actions: const [AliceInspectorButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                labelText: 'Ad veya Genel Kod ile filtrele',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (ctx, i) {
                      final s = _filteredItems[i];
                      return ListTile(
                        title: Text(s.ad),
                        subtitle: Text(s.genelKod),
                        trailing: Text(s.barkod1.isNotEmpty ? s.barkod1 : '-'),
                        onTap: () => _onItemTap(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BarkodDialog extends StatefulWidget {
  const _BarkodDialog({required this.stok});
  final StokMaster stok;

  @override
  State<_BarkodDialog> createState() => _BarkodDialogState();
}

class _BarkodDialogState extends State<_BarkodDialog> {
  final TextEditingController _barkodController = TextEditingController();
  final FocusNode _barkodFocus = FocusNode(debugLabel: 'BarkodInput');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _barkodFocus.addListener(() {
      if (_barkodFocus.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barkodFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _barkodController.dispose();
    _barkodFocus.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final barkod = _barkodController.text.trim();
    if (barkod.isEmpty) return;

    final ctx = context;
    final dbProvider =
        Provider.of<SelectedDatabaseProvider>(ctx, listen: false);
    final dbId = dbProvider.selectedDatabase?.id;
    if (dbId == null) return;
    final token = await StorageService.getToken();
    if (token == null) return;

    setState(() => _isSaving = true);
    try {
      await ApiService.stokBarkodKaydet(token, dbId, widget.stok.genelKod, barkod);
      if (!mounted) return;
      Navigator.of(ctx).pop();
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Barkod kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stok.ad, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.stok.genelKod,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _barkodController,
            focusNode: _barkodFocus,
            decoration: const InputDecoration(
              labelText: 'Barkod okutunuz',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _kaydet(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _kaydet,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
