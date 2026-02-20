'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const FeeTrackerApp());
}

class FeeTrackerApp extends StatelessWidget {
  const FeeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fee Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class Student {
  String id;
  String name;
  String phone;
  String parentPhone;
  double feeAmount;
  double paidAmount;
  DateTime admissionDate;
  DateTime? lastPaymentDate;
  String subject;
  String batch;

  Student({
    required this.id,
    required this.name,
    required this.phone,
    required this.parentPhone,
    required this.feeAmount,
    required this.paidAmount,
    required this.admissionDate,
    this.lastPaymentDate,
    required this.subject,
    required this.batch,
  });

  double get pendingAmount => feeAmount - paidAmount;
  bool get isPaid => paidAmount >= feeAmount;

  bool get isOverdue {
    if (isPaid) return false;
    final checkDate = lastPaymentDate ?? admissionDate;
    return DateTime.now().difference(checkDate).inDays > 30;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'parentPhone': parentPhone,
        'feeAmount': feeAmount,
        'paidAmount': paidAmount,
        'admissionDate': admissionDate.toIso8601String(),
        'lastPaymentDate': lastPaymentDate?.toIso8601String(),
        'subject': subject,
        'batch': batch,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        parentPhone: json['parentPhone'],
        feeAmount: json['feeAmount'].toDouble(),
        paidAmount: json['paidAmount'].toDouble(),
        admissionDate: DateTime.parse(json['admissionDate']),
        lastPaymentDate: json['lastPaymentDate'] != null
            ? DateTime.parse(json['lastPaymentDate'])
            : null,
        subject: json['subject'],
        batch: json['batch'],
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Student> students = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('students');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        students = decoded.map((e) => Student.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveStudents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'students', jsonEncode(students.map((e) => e.toJson()).toList()));
  }

  void _addStudent(Student student) {
    setState(() => students.add(student));
    _saveStudents();
  }

  void _updateStudent(Student student) {
    final index = students.indexWhere((s) => s.id == student.id);
    if (index != -1) {
      setState(() => students[index] = student);
      _saveStudents();
    }
  }

  void _deleteStudent(String id) {
    setState(() => students.removeWhere((s) => s.id == id));
    _saveStudents();
  }

  @override
  Widget build(BuildContext context) {
    final overdueStudents = students.where((s) => s.isOverdue).toList();
    final paidStudents = students.where((s) => s.isPaid).toList();
    final unpaidStudents =
        students.where((s) => !s.isPaid && !s.isOverdue).toList();

    return Scaffold(
      body: _selectedIndex == 0
          ? DashboardTab(
              students: students,
              overdueStudents: overdueStudents,
              paidStudents: paidStudents,
              unpaidStudents: unpaidStudents,
              onAddStudent: _addStudent,
              onUpdateStudent: _updateStudent,
              onDeleteStudent: _deleteStudent,
            )
          : StudentListTab(
              students: students,
              onAddStudent: _addStudent,
              onUpdateStudent: _updateStudent,
              onDeleteStudent: _deleteStudent,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Students'),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  final List<Student> students;
  final List<Student> overdueStudents;
  final List<Student> paidStudents;
  final List<Student> unpaidStudents;
  final Function(Student) onAddStudent;
  final Function(Student) onUpdateStudent;
  final Function(String) onDeleteStudent;

  const DashboardTab({
    super.key,
    required this.students,
    required this.overdueStudents,
    required this.paidStudents,
    required this.unpaidStudents,
    required this.onAddStudent,
    required this.onUpdateStudent,
    required this.onDeleteStudent,
  });

  @override
  Widget build(BuildContext context) {
    final totalFee =
        students.fold<double>(0, (sum, s) => sum + s.feeAmount);
    final totalCollected =
        students.fold<double>(0, (sum, s) => sum + s.paidAmount);
    final totalPending = totalFee - totalCollected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Tracker',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (overdueStudents.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${overdueStudents.length}'),
                child: const Icon(Icons.notifications),
              ),
              onPressed: () => _showOverdueSheet(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: _StatCard(
                      'Total Students',
                      '${students.length}',
                      Icons.people,
                      const Color(0xFF6C63FF))),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard('Overdue', '${overdueStudents.length}',
                      Icons.warning, Colors.red)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _StatCard(
                      'Total Fee',
                      '₹${totalFee.toStringAsFixed(0)}',
                      Icons.account_balance_wallet,
                      Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      'Collected',
                      '₹${totalCollected.toStringAsFixed(0)}',
                      Icons.check_circle,
                      Colors.green)),
            ]),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending Amount',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text('₹${totalPending.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                  ],
                ),
              ),
            ),
            if (overdueStudents.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('⚠️ Overdue Students',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...overdueStudents.map((s) => _OverdueCard(student: s)),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStudent(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }

  void _showOverdueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Overdue Students',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: overdueStudents.length,
              itemBuilder: (_, i) =>
                  _OverdueCard(student: overdueStudents[i]),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStudent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStudentScreen(onSave: onAddStudent),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final Student student;
  const _OverdueCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red,
          child: Text(student.name[0],
              style: const TextStyle(color: Colors.white)),
        ),
        title: Text(student.name),
        subtitle: Text('Pending: ₹${student.pendingAmount.toStringAsFixed(0)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              onPressed: () => _sendWhatsApp(student.phone,
                  'Dear ${student.name}, your fee of ₹${student.pendingAmount.toStringAsFixed(0)} is overdue. Please pay soon.'),
            ),
            IconButton(
              icon: const Icon(Icons.family_restroom, color: Colors.blue),
              onPressed: () => _sendWhatsApp(student.parentPhone,
                  'Dear Parent, ${student.name}\'s fee of ₹${student.pendingAmount.toStringAsFixed(0)} is overdue. Please pay soon.'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsApp(String phone, String message) async {
    final url =
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}

class StudentListTab extends StatefulWidget {
  final List<Student> students;
  final Function(Student) onAddStudent;
  final Function(Student) onUpdateStudent;
  final Function(String) onDeleteStudent;

  const StudentListTab({
    super.key,
    required this.students,
    required this.onAddStudent,
    required this.onUpdateStudent,
    required this.onDeleteStudent,
  });

  @override
  State<StudentListTab> createState() => _StudentListTabState();
}

class _StudentListTabState extends State<StudentListTab> {
  String _filter = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    var filtered = widget.students.where((s) {
      final matchSearch =
          s.name.toLowerCase().contains(_search.toLowerCase()) ||
              s.batch.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'All'
          ? true
          : _filter == 'Paid'
              ? s.isPaid
              : _filter == 'Overdue'
                  ? s.isOverdue
                  : !s.isPaid;
      return matchSearch && matchFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search student or batch...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['All', 'Paid', 'Unpaid', 'Overdue'].map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No students found'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _StudentCard(
                      student: filtered[i],
                      onUpdate: widget.onUpdateStudent,
                      onDelete: widget.onDeleteStudent,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  AddStudentScreen(onSave: widget.onAddStudent)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final Function(Student) onUpdate;
  final Function(String) onDelete;

  const _StudentCard(
      {required this.student, required this.onUpdate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = student.isPaid
        ? Colors.green
        : student.isOverdue
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(student.name[0],
              style: const TextStyle(color: Colors.white)),
        ),
        title: Text(student.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${student.batch} | ₹${student.pendingAmount.toStringAsFixed(0)} pending'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: Text(
              student.isPaid
                  ? 'PAID'
                  : student.isOverdue
                      ? 'OVERDUE'
                      : 'PENDING',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow('Subject', student.subject),
                _InfoRow('Phone', student.phone),
                _InfoRow('Parent Phone', student.parentPhone),
                _InfoRow('Total Fee', '₹${student.feeAmount.toStringAsFixed(0)}'),
                _InfoRow('Paid', '₹${student.paidAmount.toStringAsFixed(0)}'),
                _InfoRow('Pending', '₹${student.pendingAmount.toStringAsFixed(0)}'),
                _InfoRow(
                    'Admission',
                    DateFormat('dd MMM yyyy')
                        .format(student.admissionDate)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.message, color: Colors.green),
                        label: const Text('Student'),
                        onPressed: () => _sendWhatsApp(
                            student.phone,
                            'Dear ${student.name}, your fee of ₹${student.pendingAmount.toStringAsFixed(0)} is due. Please pay soon.'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.family_restroom,
                            color: Colors.blue),
                        label: const Text('Parent'),
                        onPressed: () => _sendWhatsApp(
                            student.parentPhone,
                            'Dear Parent, ${student.name}\'s fee of ₹${student.pendingAmount.toStringAsFixed(0)} is due. Please pay soon.'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('Add Payment'),
                        onPressed: () =>
                            _showPaymentDialog(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Payment'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Amount', prefixText: '₹'),
        ),
      
