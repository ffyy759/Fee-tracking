import 'package:flutter/material.dart';
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
    await prefs.setString('students',
        jsonEncode(students.map((e) => e.toJson()).toList()));
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
    return Scaffold(
      body: _selectedIndex == 0
          ? DashboardTab(
              students: students,
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
          NavigationDestination(
              icon: Icon(Icons.people), label: 'Students'),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  final List<Student> students;
  final Function(Student) onAddStudent;
  final Function(Student) onUpdateStudent;
  final Function(String) onDeleteStudent;

  const DashboardTab({
    super.key,
    required this.students,
    required this.onAddStudent,
    required this.onUpdateStudent,
    required this.onDeleteStudent,
  });

  @override
  Widget build(BuildContext context) {
    final overdueStudents = students.where((s) => s.isOverdue).toList();
    final totalFee = students.fold<double>(0, (sum, s) => sum + s.feeAmount);
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
              onPressed: () => _showOverdueSheet(context, overdueStudents),
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
                  child: _StatCard('Total', '${students.length}',
                      Icons.people, const Color(0xFF6C63FF))),
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
                      'Rs${totalFee.toStringAsFixed(0)}',
                      Icons.account_balance_wallet,
                      Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      'Collected',
                      'Rs${totalCollected.toStringAsFixed(0)}',
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
                        style: TextStyle(color: Colors.grey)),
                    Text('Rs${totalPending.toStringAsFixed(0)}',
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
              const Text('Overdue Students',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...overdueStudents
                  .map((s) => _OverdueCard(student: s)),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) =>
                    AddStudentScreen(onSave: onAddStudent))),
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }

  void _showOverdueSheet(
      BuildContext context, List<Student> overdueStudents) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Overdue Students',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
        subtitle: Text(
            'Pending: Rs${student.pendingAmount.toStringAsFixed(0)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              onPressed: () => _sendWhatsApp(
                  student.phone,
                  'Dear ${student.name}, your fee of Rs${student.pendingAmount.toStringAsFixed(0)} is overdue.'),
            ),
            IconButton(
              icon: const Icon(Icons.family_restroom, color: Colors.blue),
              onPressed: () => _sendWhatsApp(
                  student.parentPhone,
                  'Dear Parent, ${student.name} fee of Rs${student.pendingAmount.toStringAsFixed(0)} is overdue.'),
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
    final filtered = widget.students.where((s) {
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
                    borderRadius:
                        BorderRadius.all(Radius.circular(12))),
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
                    AddStudentScreen(onSave: widget.onAddStudent))),
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
      {required this.student,
      required this.onUpdate,
      required this.onDelete});

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
        subtitle: Text(
            '${student.batch} | Rs${student.pendingAmount.toStringAsFixed(0)} pending'),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: Text(
              student.isPaid
                  ? 'PAID'
                  : student.isOverdue
                      ? 'OVERDUE'
                      : 'PENDING',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow('Subject', student.subject),
                _InfoRow('Phone', student.phone),
                _InfoRow('Parent', student.parentPhone),
                _InfoRow('Total Fee',
                    'Rs${student.feeAmount.toStringAsFixed(0)}'),
                _InfoRow('Paid',
                    'Rs${student.paidAmount.toStringAsFixed(0)}'),
                _InfoRow('Pending',
                    'Rs${student.pendingAmount.toStringAsFixed(0)}'),
                _InfoRow(
                    'Admission',
                    DateFormat('dd MMM yyyy')
                        .format(student.admissionDate)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.message,
                            color: Colors.green),
                        label: const Text('Student'),
                        onPressed: () => _sendWhatsApp(
                            student.phone,
                            'Dear ${student.name}, fee of Rs${student.pendingAmount.toStringAsFixed(0)} is due.'),
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
                            'Dear Parent, ${student.name} fee of Rs${student.pendingAmount.toStringAsFixed(0)} is due.'),
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
                      icon: const Icon(Icons.delete,
                          color: Colors.red),
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
              labelText: 'Amount', prefixText: 'Rs'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount =
                  double.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                onUpdate(Student(
                  id: student.id,
                  name: student.name,
                  phone: student.phone,
                  parentPhone: student.parentPhone,
                  feeAmount: student.feeAmount,
                  paidAmount: student.paidAmount + amount,
                  admissionDate: student.admissionDate,
                  lastPaymentDate: DateTime.now(),
                  subject: student.subject,
                  batch: student.batch,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Student?'),
        content:
            Text('${student.name} will be deleted permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () {
              onDelete(student.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class AddStudentScreen extends StatefulWidget {
  final Function(Student) onSave;
  const AddStudentScreen({super.key, required this.onSave});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _parentPhone = TextEditingController();
  final _fee = TextEditingController();
  final _subject = TextEditingController();
  final _batch = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Add Student',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Student Name', Icons.person),
            _field(_phone, 'Student Phone (with country code)',
                Icons.phone, TextInputType.phone),
            _field(_parentPhone,
                'Parent Phone (with country code)',
                Icons.family_restroom, TextInputType.phone),
            _field(_fee, 'Monthly Fee', Icons.currency_rupee,
                TextInputType.number),
            _field(_subject, 'Subject', Icons.book),
            _field(_batch, 'Batch', Icons.group),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16)),
              icon: const Icon(Icons.save),
              label: const Text('Save Student',
                  style: TextStyle(fontSize: 16)),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      IconData icon,
      [TextInputType type = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(12))),
        ),
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(Student(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _name.text,
        phone: _phone.text,
        parentPhone: _parentPhone.text,
        feeAmount: double.parse(_fee.text),
        paidAmount: 0,
        admissionDate: DateTime.now(),
        subject: _subject.text,
        batch: _batch.text,
      ));
      Navigator.pop(context);
    }
  }
}
