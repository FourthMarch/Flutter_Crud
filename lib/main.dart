import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Toko',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

// ==========================================
// 1. MODEL DATA (BARANG)
// ==========================================
class Barang {
  final int? id;
  final String nama;
  final int harga;
  final int stok;

  Barang({
    this.id,
    required this.nama,
    required this.harga,
    required this.stok,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'nama': nama, 'harga': harga, 'stok': stok};
  }

  factory Barang.fromMap(Map<String, dynamic> map) {
    return Barang(
      id: map['id'],
      nama: map['nama'],
      harga: map['harga'],
      stok: map['stok'],
    );
  }
}

// ==========================================
// 2. DATABASE HELPER (SQLITE)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // UBAH DISINI: Gunakan 'p.join' karena kita meng-alias import path menjadi 'p'
    String path = p.join(await getDatabasesPath(), 'toko_database.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE barang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT,
        harga INTEGER,
        stok INTEGER
      )
    ''');
  }

  Future<int> insertBarang(Barang barang) async {
    Database db = await database;
    return await db.insert('barang', barang.toMap());
  }

  Future<List<Barang>> getBarangList() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'barang',
      orderBy: "id DESC",
    );
    return List.generate(maps.length, (i) {
      return Barang.fromMap(maps[i]);
    });
  }

  Future<int> updateBarang(Barang barang) async {
    Database db = await database;
    return await db.update(
      'barang',
      barang.toMap(),
      where: 'id = ?',
      whereArgs: [barang.id],
    );
  }

  Future<int> deleteBarang(int id) async {
    Database db = await database;
    return await db.delete('barang', where: 'id = ?', whereArgs: [id]);
  }
}

// ==========================================
// 3. UI UTAMA (HOME PAGE)
// ==========================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Barang> _listBarang = [];
  bool _isLoading = true;

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _stokController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshBarangList();
  }

  void _refreshBarangList() async {
    final data = await _dbHelper.getBarangList();
    setState(() {
      _listBarang = data;
      _isLoading = false;
    });
  }

  void _showForm(int? id) async {
    if (id != null) {
      final existingBarang = _listBarang.firstWhere(
        (element) => element.id == id,
      );
      _namaController.text = existingBarang.nama;
      _hargaController.text = existingBarang.harga.toString();
      _stokController.text = existingBarang.stok.toString();
    } else {
      _namaController.clear();
      _hargaController.clear();
      _stokController.clear();
    }

    showModalBottomSheet(
      context: context,
      elevation: 5,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          top: 15,
          left: 15,
          right: 15,
          bottom: MediaQuery.of(context).viewInsets.bottom + 120,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(hintText: 'Nama Barang'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _hargaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Harga (Rp)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stokController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Stok Barang'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // 1. Validasi Input Kosong
                if (_namaController.text.isEmpty ||
                    _hargaController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama dan Harga wajib diisi!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // 2. Validasi Input Angka (Mencegah Crash)
                if (int.tryParse(_hargaController.text) == null ||
                    (_stokController.text.isNotEmpty &&
                        int.tryParse(_stokController.text) == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Harga dan Stok harus berupa angka!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Simpan Data
                if (id == null) {
                  await _addItem();
                } else {
                  await _updateItem(id);
                }

                if (!mounted) return;
                Navigator.of(context).pop();
                _refreshBarangList();
              },
              child: Text(id == null ? 'Tambah Baru' : 'Update Data'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    // Gunakan tryParse agar aman jika user input aneh, default ke 0
    await _dbHelper.insertBarang(
      Barang(
        nama: _namaController.text,
        harga: int.tryParse(_hargaController.text) ?? 0,
        stok: int.tryParse(_stokController.text) ?? 0,
      ),
    );
  }

  Future<void> _updateItem(int id) async {
    await _dbHelper.updateBarang(
      Barang(
        id: id,
        nama: _namaController.text,
        harga: int.tryParse(_hargaController.text) ?? 0,
        stok: int.tryParse(_stokController.text) ?? 0,
      ),
    );
  }

  void _deleteItem(int id) async {
    await _dbHelper.deleteBarang(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Barang berhasil dihapus!')));
    _refreshBarangList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gudang Toko Saya'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listBarang.isEmpty
          ? const Center(child: Text("Belum ada barang, silakan tambah."))
          : ListView.builder(
              itemCount: _listBarang.length,
              itemBuilder: (context, index) => Card(
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      _listBarang[index].nama.isNotEmpty
                          ? _listBarang[index].nama[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    _listBarang[index].nama,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Harga: Rp ${_listBarang[index].harga} | Stok: ${_listBarang[index].stok}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showForm(_listBarang[index].id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Barang?'),
                            content: const Text(
                              'Anda yakin ingin menghapus barang ini?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _deleteItem(_listBarang[index].id!);
                                  Navigator.of(ctx).pop();
                                },
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(null),
      ),
    );
  }
}
