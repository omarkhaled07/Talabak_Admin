import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AdminPharmaciesScreen extends StatefulWidget {
  const AdminPharmaciesScreen({super.key});

  @override
  State<AdminPharmaciesScreen> createState() => _AdminPharmaciesScreenState();
}

class _AdminPharmaciesScreenState extends State<AdminPharmaciesScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _deliveryTimeController = TextEditingController();
  final TextEditingController _openingHoursController = TextEditingController();
  bool _isFeatured = false;
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

  void _showAddPharmacyDialog({DocumentSnapshot? pharmacy}) {
    if (pharmacy != null) {
      _nameController.text = pharmacy['name'] ?? '';
      _addressController.text = pharmacy['address'] ?? '';
      _phoneController.text = pharmacy['phone'] ?? '';
      _deliveryTimeController.text = pharmacy['deliveryTime'] ?? '';
      _openingHoursController.text = pharmacy['openingHours'] ?? '';
      _isFeatured = pharmacy['isFeatured'] ?? false;
      _imageFile = null;
    } else {
      _nameController.clear();
      _addressController.clear();
      _phoneController.clear();
      _deliveryTimeController.clear();
      _openingHoursController.clear();
      _isFeatured = false;
      _imageFile = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                pharmacy == null ? 'إضافة صيدلية' : 'تعديل صيدلية',
                textDirection: TextDirection.rtl,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_imageFile != null)
                      Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else if (pharmacy != null && pharmacy['imageUrl'] != null)
                      Image.network(
                        pharmacy['imageUrl'],
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('اختر صورة'),
                    ),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصيدلية',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: _deliveryTimeController,
                      decoration: const InputDecoration(
                        labelText: 'وقت التوصيل',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    TextField(
                      controller: _openingHoursController,
                      decoration: const InputDecoration(
                        labelText: 'ساعات العمل',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    CheckboxListTile(
                      title: const Text('مميز', textDirection: TextDirection.rtl),
                      value: _isFeatured,
                      onChanged: (value) {
                        setState(() {
                          _isFeatured = value ?? false;
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
                    if (_nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال اسم الصيدلية')),
                      );
                      return;
                    }

                    setState(() => _isLoading = true);
                    try {
                      String? imageUrl;

                      if (_imageFile != null) {
                        imageUrl = await _uploadImageToImgBB(_imageFile!);
                      } else if (pharmacy != null) {
                        imageUrl = pharmacy['imageUrl'];
                      }

                      final data = {
                        'name': _nameController.text,
                        'address': _addressController.text,
                        'phone': _phoneController.text,
                        'deliveryTime': _deliveryTimeController.text,
                        'openingHours': _openingHoursController.text,
                        'isFeatured': _isFeatured,
                        'imageUrl': imageUrl ?? 'https://via.placeholder.com/150',
                      };

                      if (pharmacy == null) {
                        await FirebaseFirestore.instance
                            .collection('entities')
                            .doc('pharmacies')
                            .collection('items')
                            .add(data);
                      } else {
                        await FirebaseFirestore.instance
                            .collection('entities')
                            .doc('pharmacies')
                            .collection('items')
                            .doc(pharmacy.id)
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
        title: const Text('إدارة الصيدليات',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff112b16),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddPharmacyDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('entities')
            .doc('pharmacies')
            .collection('items')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد صيدليات',
                textDirection: TextDirection.rtl));
          }

          final pharmacies = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pharmacies.length,
            itemBuilder: (context, index) {
              final pharmacy = pharmacies[index];
              final data = pharmacy.data() as Map<String, dynamic>;
              return ListTile(
                leading: Image.network(
                  data['imageUrl'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.local_pharmacy),
                ),
                title: Text(data['name'] ?? 'غير معروف',
                    textDirection: TextDirection.rtl),
                subtitle: Text(data['address'] ?? 'غير متوفر',
                    textDirection: TextDirection.rtl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddPharmacyDialog(pharmacy: pharmacy),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('entities')
                            .doc('pharmacies')
                            .collection('items')
                            .doc(pharmacy.id)
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
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _deliveryTimeController.dispose();
    _openingHoursController.dispose();
    super.dispose();
  }
}