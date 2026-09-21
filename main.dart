import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xFF74B89A);
const pink = Color(0xFFF3B8C9);
const cream = Color(0xFFFFFBF7);
const dark = Color(0xFF26332D);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(ScadenzarioApp(store: store));
}

class ExpiryItem {
  final String id;
  String productName;
  DateTime expiryDate;

  ExpiryItem({
    required this.id,
    required this.productName,
    required this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': productName,
        'expiryDate': expiryDate.toIso8601String(),
      };

  factory ExpiryItem.fromJson(Map<String, dynamic> j) => ExpiryItem(
        id: j['id'],
        productName: j['productName'],
        expiryDate: DateTime.parse(j['expiryDate']),
      );
}

class AppStore extends ChangeNotifier {
  late SharedPreferences prefs;
  List<ExpiryItem> items = [];
  String storeName = 'Scadenzario by DC';
  String storeCode = '';
  String? logoPath;

  static Future<AppStore> load() async {
    final s = AppStore();
    s.prefs = await SharedPreferences.getInstance();
    s.storeName = s.prefs.getString('storeName') ?? 'Scadenzario by DC';
    s.storeCode = s.prefs.getString('storeCode') ?? '';
    s.logoPath = s.prefs.getString('logoPath');
    final raw = s.prefs.getString('items');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      s.items = list.map((e) => ExpiryItem.fromJson(e)).toList();
    }
    return s;
  }

  bool get configured => storeCode.length == 4;

  Future<void> save() async {
    await prefs.setString('storeName', storeName);
    await prefs.setString('storeCode', storeCode);
    if (logoPath == null) {
      await prefs.remove('logoPath');
    } else {
      await prefs.setString('logoPath', logoPath!);
    }
    await prefs.setString(
      'items',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> addItem(String name, DateTime date) async {
    items.add(ExpiryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      productName: name.trim(),
      expiryDate: DateTime(date.year, date.month, date.day),
    ));
    await save();
  }

  Future<void> updateItem(ExpiryItem item) async => save();

  Future<void> deleteItem(ExpiryItem item) async {
    items.removeWhere((e) => e.id == item.id);
    await save();
  }

  List<ExpiryItem> forDay(DateTime d) {
    return items.where((e) =>
        e.expiryDate.year == d.year &&
        e.expiryDate.month == d.month &&
        e.expiryDate.day == d.day).toList()
      ..sort((a, b) => a.productName.compareTo(b.productName));
  }
}

class ScadenzarioApp extends StatelessWidget {
  final AppStore store;
  const ScadenzarioApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: store.storeName,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cream,
          colorScheme: ColorScheme.fromSeed(seedColor: green),
          fontFamily: 'sans',
          appBarTheme: const AppBarTheme(
            backgroundColor: cream,
            foregroundColor: dark,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: store.configured
            ? HomeScreen(store: store)
            : SetupScreen(store: store),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  final AppStore store;
  const SetupScreen({super.key, required this.store});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final code = TextEditingController();
  String? error;

  Future<void> save() async {
    if (code.text.length != 4 || int.tryParse(code.text) == null) {
      setState(() => error = 'Inserisci un codice numerico di 4 cifre.');
      return;
    }
    widget.store.storeCode = code.text;
    await widget.store.save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(Icons.event_available_rounded,
                      size: 72, color: green),
                  const SizedBox(height: 18),
                  const Text('Scadenzario by DC',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text(
                    'Configuriamo il tuo negozio.\nIl codice serve solo per la prima configurazione.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: false,
                    decoration: InputDecoration(
                      labelText: 'Codice negozio (4 cifre)',
                      errorText: error,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: save,
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: const Text('INIZIA'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});

  String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = store.forDay(now).length;
    final tomorrow = store.forDay(now.add(const Duration(days: 1))).length;
    final next3 = List.generate(3, (i) => store.forDay(now.add(Duration(days: i + 1))))
        .fold<int>(0, (a, b) => a + b.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(store.storeName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(store: store)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Logo(store: store, size: 82),
          ),
          const SizedBox(height: 18),
          ActionCard(
            icon: Icons.camera_alt_rounded,
            title: 'SCANSIONA PRODOTTO',
            subtitle: 'Inserisci prodotto e data di scadenza',
            color: green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ScannerScreen(store: store)),
            ),
          ),
          const SizedBox(height: 14),
          ActionCard(
            icon: Icons.calendar_month_rounded,
            title: 'AGENDA 14 GIORNI',
            subtitle: 'Controlla tutte le scadenze',
            color: pink,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AgendaScreen(store: store)),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              SummaryCard(label: 'OGGI', value: '$today', color: green),
              const SizedBox(width: 10),
              SummaryCard(label: 'DOMANI', value: '$tomorrow', color: pink),
              const SizedBox(width: 10),
              SummaryCard(label: 'PROSSIMI 3', value: '$next3', color: Colors.amber.shade300),
            ],
          ),
          const SizedBox(height: 24),
          Text('Scadenze di oggi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 10),
          if (store.forDay(now).isEmpty)
            const EmptyCard(text: 'Nessun prodotto in scadenza oggi 🎉')
          else
            ...store.forDay(now).map((e) => ProductTile(store: store, item: e)),
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: color.withValues(alpha: .20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color,
                  child: Icon(icon, color: dark, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}

class SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const SummaryCard(
      {super.key,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class EmptyCard extends StatelessWidget {
  final String text;
  const EmptyCard({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(text),
        ),
      );
}

class Logo extends StatelessWidget {
  final AppStore store;
  final double size;
  const Logo({super.key, required this.store, required this.size});

  @override
  Widget build(BuildContext context) {
    final path = store.logoPath;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .25),
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: green.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(size * .25),
      ),
      child: const Icon(Icons.storefront_rounded, color: green, size: 42),
    );
  }
}

class AgendaScreen extends StatelessWidget {
  final AppStore store;
  const AgendaScreen({super.key, required this.store});

  String dayName(DateTime d) {
    const names = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    return names[d.weekday - 1];
  }

  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final start = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda 14 giorni')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: 14,
        itemBuilder: (_, i) {
          final d = DateTime(start.year, start.month, start.day + i);
          final list = store.forDay(d);
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              initiallyExpanded: i < 2,
              title: Text(dayName(d),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${fmt(d)} • ${list.length} prodotti'),
              children: list.isEmpty
                  ? [const ListTile(title: Text('Nessuna scadenza'))]
                  : list
                      .map((e) => ProductTile(store: store, item: e))
                      .toList(),
            ),
          );
        },
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  final AppStore store;
  final ExpiryItem item;
  const ProductTile({super.key, required this.store, required this.item});

  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE9F5EE),
          child: Icon(Icons.inventory_2_outlined, color: green),
        ),
        title: Text(item.productName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Scadenza: ${fmt(item.expiryDate)}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') {
              await store.deleteItem(item);
            } else {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConfirmProductScreen(store: store, item: item),
                ),
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Modifica')),
            PopupMenuItem(value: 'delete', child: Text('Elimina')),
          ],
        ),
      );
}

class ScannerScreen extends StatefulWidget {
  final AppStore store;
  const ScannerScreen({super.key, required this.store});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final controller = MobileScannerController();
  bool opened = false;

  void manualEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ConfirmProductScreen(store: widget.store)),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scansione prodotto')),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (opened || capture.barcodes.isEmpty) return;
                opened = true;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfirmProductScreen(
                      store: widget.store,
                      initialName: capture.barcodes.first.rawValue ?? '',
                    ),
                  ),
                ).then((_) => opened = false);
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(22),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .68),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Inquadra il prodotto.\nPuoi anche inserire i dati manualmente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: manualEntry,
                      child: const Text('INSERISCI MANUALMENTE'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class ConfirmProductScreen extends StatefulWidget {
  final AppStore store;
  final ExpiryItem? item;
  final String initialName;
  const ConfirmProductScreen({
    super.key,
    required this.store,
    this.item,
    this.initialName = '',
  });

  @override
  State<ConfirmProductScreen> createState() => _ConfirmProductScreenState();
}

class _ConfirmProductScreenState extends State<ConfirmProductScreen> {
  late TextEditingController name;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.item?.productName ?? widget.initialName,
    );
    date = widget.item?.expiryDate ??
        DateTime.now().add(const Duration(days: 1));
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    if (widget.item != null) {
      widget.item!
        ..productName = name.text.trim()
        ..expiryDate = date;
      await widget.store.updateItem(widget.item!);
    } else {
      await widget.store.addItem(name.text.trim(), date);
    }
    if (mounted) Navigator.pop(context);
  }

  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Conferma prodotto')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Icon(Icons.fact_check_outlined, size: 64, color: green),
            const SizedBox(height: 18),
            const Text('Controlla i dati',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nome prodotto',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.event_outlined, color: green),
                title: const Text('Data di scadenza'),
                subtitle: Text(fmt(date)),
                trailing: OutlinedButton(
                  onPressed: pickDate,
                  child: const Text('MODIFICA'),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: save,
              style: FilledButton.styleFrom(
                backgroundColor: green,
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('CONFERMA E SALVA'),
            ),
          ],
        ),
      );
}

class SettingsScreen extends StatefulWidget {
  final AppStore store;
  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController storeName;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    storeName = TextEditingController(text: widget.store.storeName);
  }

  Future<void> chooseLogo() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    widget.store.logoPath = x.path;
    await widget.store.save();
    setState(() {});
  }

  Future<void> saveName() async {
    widget.store.storeName = storeName.text.trim().isEmpty
        ? 'Scadenzario by DC'
        : storeName.text.trim();
    await widget.store.save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Impostazioni')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Center(child: Logo(store: widget.store, size: 110)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: chooseLogo,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('CAMBIA LOGO'),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: storeName,
              decoration: const InputDecoration(
                labelText: 'Nome del negozio',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              onSubmitted: (_) => saveName(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saveName,
              style: FilledButton.styleFrom(backgroundColor: green),
              child: const Text('SALVA NOME'),
            ),
            const SizedBox(height: 28),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: green),
                title: const Text('Codice negozio'),
                subtitle: Text(widget.store.storeCode),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'I dati vengono salvati sul telefono. Non è richiesto un account e non c’è sincronizzazione cloud.',
                ),
              ),
            ),
          ],
        ),
      );
}
