import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_products_screen.dart';

class AdminCategoriesScreen extends StatefulWidget {
  final String entityId;
  final String entityName;
  final String entityCollection;

  const AdminCategoriesScreen({
    Key? key,
    required this.entityId,
    required this.entityName,
    required this.entityCollection,
  }) : super(key: key);

  @override
  _AdminCategoriesScreenState createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
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

  Future<void> _addCategory() async {
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
            .add({
              'name': _nameController.text.trim(),
              'imageUrl': imageUrl ?? 'https://via.placeholder.com/60',
              'createdAt': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إضافة الفئة بنجاح')));
        _nameController.clear();
        setState(() => _image = null);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCategory(String id) async {
    await FirebaseFirestore.instance
        .collection('entities')
        .doc(widget.entityCollection)
        .collection('items')
        .doc(widget.entityId)
        .collection('categories')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff112b16),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'إدارة فئات ${widget.entityName}',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body:
          _isLoading
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
                            decoration: const InputDecoration(
                              labelText: 'اسم الفئة',
                            ),
                            validator:
                                (value) =>
                                    value!.isEmpty
                                        ? 'يرجى إدخال اسم الفئة'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          _image == null
                              ? const Text('لم يتم اختيار صورة')
                              : Image.file(_image!, height: 100),
                          ElevatedButton(
                            onPressed: _pickImage,
                            child: const Text('اختر صورة'),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _addCategory,
                            child: const Text('إضافة فئة'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('entities')
                              .doc(widget.entityCollection)
                              .collection('items')
                              .doc(widget.entityId)
                              .collection('categories')
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const CircularProgressIndicator();
                        final categories = snapshot.data!.docs;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category =
                                categories[index].data()
                                    as Map<String, dynamic>;
                            return ListTile(
                              leading: Image.network(
                                category['imageUrl'] ??
                                    'https://via.placeholder.com/60',
                                width: 50,
                                height: 50,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const Icon(Icons.category),
                              ),
                              title: Text(category['name'] ?? 'غير معروف'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      // Implement edit category if needed
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed:
                                        () => _deleteCategory(
                                          categories[index].id,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.fastfood),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => AdminProductsScreen(
                                                entityId: widget.entityId,
                                                entityCollection:
                                                    widget.entityCollection,
                                                categoryId:
                                                    categories[index].id,
                                                categoryName:
                                                    category['name'] ??
                                                    'غير معروف',
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
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
    super.dispose();
  }
}
