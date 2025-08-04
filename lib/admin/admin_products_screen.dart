import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminProductsScreen extends StatefulWidget {
  final String entityId;
  final String entityCollection;
  final String categoryId;
  final String categoryName;

  const AdminProductsScreen({
    Key? key,
    required this.entityId,
    required this.entityCollection,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  _AdminProductsScreenState createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  File? _image;
  bool _isLoading = false;

  Future<String?> _uploadImageToImgBB(File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.imgbb.com/1/upload?key=2152c491ff31e06c6614b5e849328e39'),
    );
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final json = jsonDecode(responseData);
    return json['data']['url'];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String? imageUrl;
        if (_image != null) {
          imageUrl = await _uploadImageToImgBB(_image!);
        }

        await FirebaseFirestore.instance
            .collection('entities')
            .doc(widget.entityCollection)
            .collection('items')
            .doc(widget.entityId)
            .collection('categories')
            .doc(widget.categoryId)
            .collection('items')
            .add({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'imageUrl': imageUrl ?? 'https://via.placeholder.com/60',
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة المنتج بنجاح')),
        );
        _nameController.clear();
        _descriptionController.clear();
        _priceController.clear();
        setState(() => _image = null);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    await FirebaseFirestore.instance
        .collection('entities')
        .doc(widget.entityCollection)
        .collection('items')
        .doc(widget.entityId)
        .collection('categories')
        .doc(widget.categoryId)
        .collection('items')
        .doc(productId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('إدارة منتجات ${widget.categoryName}', style: TextStyle(color: Colors.white),),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'اسم المنتج'),
                    validator: (value) => value!.isEmpty ? 'يرجى إدخال اسم المنتج' : null,
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                    maxLines: 3,
                  ),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'السعر'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'يرجى إدخال السعر' : null,
                  ),
                  const SizedBox(height: 16),
                  _image == null
                      ? const Text('Failed to select an image')
                      : Image.file(_image!, height: 100),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Choose an image'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addProduct,
                    child: const Text('Add product'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('entities')
                  .doc(widget.entityCollection)
                  .collection('items')
                  .doc(widget.entityId)
                  .collection('categories')
                  .doc(widget.categoryId)
                  .collection('items')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final products = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: Image.network(
                        product['imageUrl'] ?? 'https://via.placeholder.com/60',
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood),
                      ),
                      title: Text(product['name'] ?? 'غير معروف'),
                      subtitle: Text('${product['price'] ?? 0} ج.م'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteProduct(products[index].id),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}