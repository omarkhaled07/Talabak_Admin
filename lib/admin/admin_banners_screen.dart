import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetEntityIdController = TextEditingController();
  final TextEditingController _targetEntityTypeController = TextEditingController();
  bool _isActive = true;
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToImgBB(File image) async {
    setState(() => _isLoading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgbb.com/1/upload?key=2152c491ff31e06c6614b5e849328e39'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final json = jsonDecode(responseData);

      return json['data']['url'];
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الصورة: $e')),
      );
      return null;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddBannerDialog({DocumentSnapshot? banner}) {
    if (banner != null) {
      _titleController.text = banner['title'] ?? '';
      _targetEntityIdController.text = banner['targetEntityId'] ?? '';
      _targetEntityTypeController.text = banner['targetEntityType'] ?? '';
      _isActive = banner['isActive'] ?? true;
      _imageFile = null;
    } else {
      _titleController.clear();
      _targetEntityIdController.clear();
      _targetEntityTypeController.clear();
      _isActive = true;
      _imageFile = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                banner == null ? 'إضافة بانر' : 'تعديل بانر',
                textDirection: TextDirection.rtl,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_imageFile != null)
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else if (banner != null && banner['imageUrl'] != null)
                      Image.network(
                        banner['imageUrl'],
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('اختر صورة'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان البانر',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    TextField(
                      controller: _targetEntityIdController,
                      decoration: const InputDecoration(
                        labelText: 'معرف الكيان المستهدف',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    TextField(
                      controller: _targetEntityTypeController,
                      decoration: const InputDecoration(
                        labelText: 'نوع الكيان (restaurants/pharmacies/stores/groceryStores)',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    CheckboxListTile(
                      title: const Text('نشط', textDirection: TextDirection.rtl),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_titleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال عنوان البانر')),
                      );
                      return;
                    }

                    setState(() => _isLoading = true);
                    try {
                      String? imageUrl;

                      if (_imageFile != null) {
                        imageUrl = await _uploadImageToImgBB(_imageFile!);
                      } else if (banner != null) {
                        imageUrl = banner['imageUrl'];
                      }

                      final data = {
                        'title': _titleController.text,
                        'targetEntityId': _targetEntityIdController.text,
                        'targetEntityType': _targetEntityTypeController.text,
                        'isActive': _isActive,
                        'imageUrl': imageUrl ?? 'https://via.placeholder.com/150',
                        'createdAt': FieldValue.serverTimestamp(),
                      };

                      if (banner == null) {
                        await FirebaseFirestore.instance.collection('banners').add(data);
                      } else {
                        await FirebaseFirestore.instance
                            .collection('banners')
                            .doc(banner.id)
                            .update(data);
                      }

                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('حدث خطأ: $e')),
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('إدارة البنرات',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff112b16),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddBannerDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('banners').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد بنرات', textDirection: TextDirection.rtl));
          }

          final banners = snapshot.data!.docs;

          return ListView.builder(
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              final data = banner.data() as Map<String, dynamic>;
              return ListTile(
                leading: Image.network(
                  data['imageUrl'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 24),
                  ),
                ),
                title: Text(data['title'] ?? 'غير معروف', textDirection: TextDirection.rtl),
                subtitle: Text(
                  '${data['targetEntityType'] ?? 'غير متوفر'} - ${data['isActive'] == true ? 'نشط' : 'غير نشط'}',
                  textDirection: TextDirection.rtl,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddBannerDialog(banner: banner),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('banners')
                            .doc(banner.id)
                            .delete();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetEntityIdController.dispose();
    _targetEntityTypeController.dispose();
    super.dispose();
  }
}