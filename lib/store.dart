import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class ExpenseStore {
  String get user;
  Stream<List<Map<String, dynamic>>> get groups;
  Stream<List<Map<String, dynamic>>> expenses(String? group);
  Future<void> createGroup(String name, List<String> members);
  Future<void> addExpense(String? group, Map<String, dynamic> expense);
}

class FirebaseStore implements ExpenseStore {
  final db = FirebaseFirestore.instance;
  @override
  String get user => FirebaseAuth.instance.currentUser!.email!.toLowerCase();
  @override
  Stream<List<Map<String, dynamic>>> get groups => db
      .collection('groups')
      .where('members', arrayContains: user)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  CollectionReference<Map<String, dynamic>> collection(String? group) =>
      group == null
      ? db
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('expenses')
      : db.collection('groups').doc(group).collection('expenses');
  @override
  Stream<List<Map<String, dynamic>>> expenses(String? group) =>
      collection(group).snapshots().map(
        (s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList()
          ..sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          ),
      );
  @override
  Future<void> createGroup(String name, List<String> members) async {
    await db.collection('groups').add({
      'name': name,
      'members': members,
      'owner': user,
    });
  }

  @override
  Future<void> addExpense(String? group, Map<String, dynamic> expense) async {
    await collection(group).add({...expense, 'createdBy': user});
  }
}

// Deliberately temporary: demo records disappear when the app is restarted.
class DemoStore implements ExpenseStore {
  @override
  String get user => 'you@example.com';
  final List<Map<String, dynamic>> _groups = [
    {
      'id': 'weekend',
      'name': 'Weekend crew',
      'members': ['you@example.com', 'alex@example.com', 'sam@example.com'],
    },
  ];
  final Map<String, List<Map<String, dynamic>>> _expenses = {};
  Stream<List<Map<String, dynamic>>> watch(
    List<Map<String, dynamic>> Function() read,
  ) async* {
    // A polling stream keeps the dependency-free demo simple.
    yield read();
    yield* Stream.periodic(const Duration(milliseconds: 250), (_) => read());
  }

  @override
  Stream<List<Map<String, dynamic>>> get groups =>
      watch(() => List.of(_groups));
  @override
  Stream<List<Map<String, dynamic>>> expenses(String? group) =>
      watch(() => List.of(_expenses[group ?? 'personal'] ?? []));
  @override
  Future<void> createGroup(String name, List<String> members) async {
    _groups.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'members': members,
    });
  }

  @override
  Future<void> addExpense(String? group, Map<String, dynamic> expense) async {
    _expenses.putIfAbsent(group ?? 'personal', () => []).insert(0, expense);
  }
}
