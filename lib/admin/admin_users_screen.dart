import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'user';
  String _currentUserId = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _selectedRole = 'user';
    _currentUserId = '';
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'delivery':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Future<void> _createUserWithEmailAndPassword() async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Create user document with complete structure
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'uid': userCredential.user?.uid,
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'role': _selectedRole,
        'isAdmin': _selectedRole == 'admin',
        'profileImage': '',
        'createdAt': FieldValue.serverTimestamp(),
        'orders': [],
        'addresses': [],
        'cart': [],
        'favorites': [],
      });
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'حدث خطأ في إنشاء الحساب';
    }
  }

  Future<void> _updateUser() async {
    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'role': _selectedRole,
        'isAdmin': _selectedRole == 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'حدث خطأ في التحديث';
    }
  }

  void _showUserFormDialog([DocumentSnapshot? user]) {
    if (user != null) {
      final data = user.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _selectedRole = data['role'] ?? 'user';
      _currentUserId = user.id;
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // أضف StatefulBuilder هنا
          builder: (context, setState) { // هذه setState خاصة بالديالوج
            return AlertDialog(
              title: Text(
                user == null ? 'إضافة مستخدم جديد' : 'تعديل المستخدم',
                textDirection: TextDirection.rtl,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        hintTextDirection: TextDirection.rtl,
                      ),
                      textDirection: TextDirection.rtl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: user == null,
                    ),
                    if (user == null)
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          hintTextDirection: TextDirection.rtl,
                        ),
                        textDirection: TextDirection.rtl,
                        obscureText: true,
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
                    const SizedBox(height: 16),
                    const Text(
                      'نوع المستخدم:',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.admin_panel_settings,
                              color: _selectedRole == 'admin' ? Colors.red : Colors.grey),
                          title: const Text('مسؤول', textDirection: TextDirection.rtl),
                          onTap: () {
                            setState(() { // استخدم setState الخاصة بالStatefulBuilder هنا
                              _selectedRole = 'admin';
                            });
                          },
                          selected: _selectedRole == 'admin',
                          selectedTileColor: Colors.red.withOpacity(0.1),
                        ),
                        ListTile(
                          leading: Icon(Icons.delivery_dining,
                              color: _selectedRole == 'delivery' ? Colors.blue : Colors.grey),
                          title: const Text('موزع', textDirection: TextDirection.rtl),
                          onTap: () {
                            setState(() { // استخدم setState الخاصة بالStatefulBuilder هنا
                              _selectedRole = 'delivery';
                            });
                          },
                          selected: _selectedRole == 'delivery',
                          selectedTileColor: Colors.blue.withOpacity(0.1),
                        ),
                        ListTile(
                          leading: Icon(Icons.person,
                              color: _selectedRole == 'user' ? Colors.green : Colors.grey),
                          title: const Text('مستخدم عادي', textDirection: TextDirection.rtl),
                          onTap: () {
                            setState(() { // استخدم setState الخاصة بالStatefulBuilder هنا
                              _selectedRole = 'user';
                            });
                          },
                          selected: _selectedRole == 'user',
                          selectedTileColor: Colors.green.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearForm();
                  },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.isEmpty ||
                        _emailController.text.isEmpty ||
                        _phoneController.text.isEmpty ||
                        (user == null && _passwordController.text.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الرجاء ملء جميع الحقول المطلوبة',
                              textDirection: TextDirection.rtl),
                        ),
                      );
                      return;
                    }

                    try {
                      if (user == null) {
                        await _createUserWithEmailAndPassword();
                      } else {
                        await _updateUser();
                      }
                      Navigator.pop(context);
                      _clearForm();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('حدث خطأ: $e',
                              textDirection: TextDirection.rtl),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('حفظ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'مسؤول';
      case 'delivery':
        return 'موزع';
      default:
        return 'مستخدم';
    }
  }

  Widget _buildUserDetails(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الاسم: ${data['name'] ?? 'غير متوفر'}',
            textDirection: TextDirection.rtl),
        Text('البريد: ${data['email'] ?? 'غير متوفر'}',
            textDirection: TextDirection.rtl),
        Text('الهاتف: ${data['phone'] ?? 'غير متوفر'}',
            textDirection: TextDirection.rtl),
        Text('الدور: ${_getRoleName(data['role'] ?? 'user')}',
            textDirection: TextDirection.rtl),
        _buildRatingInfo(data), // أضف هذا السطر
        const SizedBox(height: 8),
        const Text('العنوان:',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.bold)),
        if (data['addresses'] != null && (data['addresses'] as List).isNotEmpty)
          ...(data['addresses'] as List).map((address) =>
              Text('- ${address.toString()}', textDirection: TextDirection.rtl))
        else
          const Text('لا يوجد عناوين', textDirection: TextDirection.rtl),
      ],
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
        title: const Text('إدارة المستخدمين',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xff112b16),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff112b16),
        onPressed: () => _showUserFormDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث عن مستخدم',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintTextDirection: TextDirection.rtl,
              ),
              textDirection: TextDirection.rtl,
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('لا توجد مستخدمين',
                          textDirection: TextDirection.rtl));
                }

                final users = snapshot.data!.docs.where((user) {
                  final data = user.data() as Map<String, dynamic>;
                  final searchTerm = _searchController.text.toLowerCase();
                  return data['name']
                      .toString()
                      .toLowerCase()
                      .contains(searchTerm) ||
                      data['email']
                          .toString()
                          .toLowerCase()
                          .contains(searchTerm) ||
                      data['phone']
                          .toString()
                          .toLowerCase()
                          .contains(searchTerm) ||
                      _getRoleName(data['role'] ?? 'user')
                          .toLowerCase()
                          .contains(searchTerm);
                }).toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data() as Map<String, dynamic>;
                    final role = data['role'] ?? 'user';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getRoleColor(role).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getRoleColor(role),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            role == 'admin'
                                ? Icons.admin_panel_settings
                                : role == 'delivery'
                                ? Icons.delivery_dining
                                : Icons.person,
                            color: _getRoleColor(role),
                          ),
                        ),
                        title: Text(data['name'] ?? 'غير معروف',
                            textDirection: TextDirection.rtl),
                        subtitle: Text(data['email'] ?? 'غير متوفر',
                            textDirection: TextDirection.rtl),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                _getRoleName(role),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: _getRoleColor(role),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showUserFormDialog(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteUser(user),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildUserDetails(data),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRatingInfo(Map<String, dynamic> userData) {
    final ratingCount = userData['deliveryRatingCount'] ?? 0;
    final averageRating = userData['deliveryAverageRating'] ?? 0.0;

    if (userData['role'] != 'delivery' || ratingCount == 0) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('تقييمات التوصيل:',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            RatingBarIndicator(
              rating: averageRating,
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 20.0,
              direction: Axis.horizontal,
            ),
            const SizedBox(width: 8),
            Text('($averageRating من 5)',
                textDirection: TextDirection.rtl),
            const SizedBox(width: 8),
            Text('($ratingCount تقييم${ratingCount > 1 ? 'ات' : ''})',
                textDirection: TextDirection.rtl),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDeleteUser(DocumentSnapshot user) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: const Text('هل أنت متأكد من حذف هذا المستخدم؟',
            textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from Authentication first
        await FirebaseAuth.instance.currentUser!.delete();
        // Then delete from Firestore
        await _firestore.collection('users').doc(user.id).delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحذف: $e',
                textDirection: TextDirection.rtl),
          ),
        );
      }
    }
  }
}