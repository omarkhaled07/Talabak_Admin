import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  bool _isActive = true;

  void _showAddPromotionDialog({DocumentSnapshot? promotion}) {
    if (promotion != null) {
      _titleController.text = promotion['title'] ?? '';
      _descriptionController.text = promotion['description'] ?? '';
      _discountController.text = promotion['discount']?.toString() ?? '';
      _imageUrlController.text = promotion['imageUrl'] ?? '';
      _startDateController.text = promotion['startDate'] ?? '';
      _endDateController.text = promotion['endDate'] ?? '';
      _isActive = promotion['isActive'] ?? true;
    } else {
      _titleController.clear();
      _descriptionController.clear();
      _discountController.clear();
      _imageUrlController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _isActive = true;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            promotion == null ? 'إضافة عرض ترويجي' : 'تعديل عرض ترويجي',
            textDirection: TextDirection.rtl,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان العرض',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'وصف العرض',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                ),
                TextField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                    labelText: 'نسبة الخصم (%)',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'رابط الصورة',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                TextField(
                  controller: _startDateController,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ البدء (مثل: 2025-05-30)',
                    hintTextDirection: TextDirection.rtl,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                TextField(
                  controller: _endDateController,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الانتهاء (مثل: 2025-06-30)',
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
                if (_titleController.text.isEmpty ||
                    _descriptionController.text.isEmpty ||
                    _discountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى ملء جميع الحقول الأساسية', textDirection: TextDirection.rtl),
                    ),
                  );
                  return;
                }
                final data = {
                  'title': _titleController.text,
                  'description': _descriptionController.text,
                  'discount': double.tryParse(_discountController.text) ?? 0.0,
                  'imageUrl': _imageUrlController.text,
                  'startDate': _startDateController.text,
                  'endDate': _endDateController.text,
                  'isActive': _isActive,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                if (promotion == null) {
                  await FirebaseFirestore.instance.collection('promotions').add(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('promotions')
                      .doc(promotion.id)
                      .update(data);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
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
        title: const Text('إدارة العروض الترويجية', textDirection: TextDirection.rtl,style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xff112b16),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddPromotionDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('promotions').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد عروض ترويجية', textDirection: TextDirection.rtl));
          }

          final promotions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promotion = promotions[index];
              final data = promotion.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: Image.network(
                    data['imageUrl'] ?? '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_offer),
                  ),
                  title: Text(data['title'] ?? 'غير معروف', textDirection: TextDirection.rtl),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(data['description'] ?? 'غير متوفر', textDirection: TextDirection.rtl),
                      Text('الخصم: ${data['discount']}%', textDirection: TextDirection.rtl),
                      Text(
                        data['isActive'] == true ? 'نشط' : 'غير نشط',
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddPromotionDialog(promotion: promotion),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('promotions')
                              .doc(promotion.id)
                              .delete();
                        },
                      ),
                    ],
                  ),
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
    _descriptionController.dispose();
    _discountController.dispose();
    _imageUrlController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }
}