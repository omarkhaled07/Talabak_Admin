import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AdminAddGroceryStoreScreen extends StatefulWidget {
  final String? groceryStoreId;
  final Map<String, dynamic>? initialData;

  const AdminAddGroceryStoreScreen({
    Key? key,
    this.groceryStoreId,
    this.initialData,
  }) : super(key: key);

  @override
  _AdminAddGroceryStoreScreenState createState() => _AdminAddGroceryStoreScreenState();
}

class _AdminAddGroceryStoreScreenState extends State<AdminAddGroceryStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _arabicNameController = TextEditingController();
  final _deliveryTimeController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _openingHoursController = TextEditingController();
  File? _image;
  bool _isFeatured = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _arabicNameController.text = widget.initialData!['arabicName'] ?? '';
      _deliveryTimeController.text = widget.initialData!['deliveryTime'] ?? '';
      _addressController.text = widget.initialData!['address'] ?? '';
      _phoneController.text = widget.initialData!['phone'] ?? '';
      _openingHoursController.text = widget.initialData!['openingHours'] ?? '';
      _isFeatured = widget.initialData!['isFeatured'] ?? false;
    }
  }

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

  Future<void> _addGroceryStore() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String? imageUrl = widget.initialData?['imageUrl'];
        if (_image != null) {
          imageUrl = await _uploadImageToImgBB(_image!);
        }

        final data = {
          'name': _nameController.text.trim(),
          'arabicName': _arabicNameController.text.trim(),
          'imageUrl': imageUrl ?? 'https://via.placeholder.com/60',
          'deliveryTime': _deliveryTimeController.text.trim(),
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'openingHours': _openingHoursController.text.trim(),
          'isFeatured': _isFeatured,
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (widget.groceryStoreId == null) {
          await FirebaseFirestore.instance
              .collection('entities')
              .doc('groceryStores')
              .collection('items')
              .add(data);
        } else {
          await FirebaseFirestore.instance
              .collection('entities')
              .doc('groceryStores')
              .collection('items')
              .doc(widget.groceryStoreId)
              .update(data);
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ البقالة بنجاح')));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
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
          widget.groceryStoreId == null ? 'إضافة بقالة' : 'تعديل بقالة',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم البقالة (إنجليزي)',
                ),
                validator: (value) => value!.isEmpty ? 'يرجى إدخال الاسم' : null,
              ),
              TextFormField(
                controller: _arabicNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم البقالة (عربي)',
                ),
                validator: (value) => value!.isEmpty ? 'يرجى إدخال الاسم' : null,
              ),
              TextFormField(
                controller: _deliveryTimeController,
                decoration: const InputDecoration(
                  labelText: 'وقت التوصيل',
                ),
                validator: (value) => value!.isEmpty ? 'يرجى إدخال وقت التوصيل' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
                validator: (value) => value!.isEmpty ? 'يرجى إدخال العنوان' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
              ),
              TextFormField(
                controller: _openingHoursController,
                decoration: const InputDecoration(
                  labelText: 'ساعات العمل',
                ),
              ),
              SwitchListTile(
                title: const Text('مميز'),
                value: _isFeatured,
                onChanged: (value) => setState(() => _isFeatured = value),
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
                onPressed: _addGroceryStore,
                child: Text(
                  widget.groceryStoreId == null ? 'إضافة' : 'تحديث',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _arabicNameController.dispose();
    _deliveryTimeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _openingHoursController.dispose();
    super.dispose();
  }
}