import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ledger.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var connected = false;
  if (const bool.fromEnvironment('FIREBASE_ENABLED')) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      ),
    );
    connected = true;
  }
  runApp(ExpenseApp(connected: connected));
}

String money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

class ExpenseApp extends StatelessWidget {
  final bool connected;
  const ExpenseApp({super.key, this.connected = false});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Together • Expenses',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff227567)),
      scaffoldBackgroundColor: const Color(0xfff5f7f4),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: connected
        ? StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) => snapshot.data == null
                ? const AuthScreen()
                : Home(store: FirebaseStore()),
          )
        : Home(store: DemoStore(), demo: true),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (register) {
        final result = await auth.createUserWithEmailAndPassword(
          email: email.text.trim().toLowerCase(),
          password: password.text,
        );
        await result.user!.sendEmailVerification();
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim().toLowerCase(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Sign-in failed. Check your details and connection.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 64),
              const SizedBox(height: 24),
              Text(
                'Together',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const Text(
                'Your money. Your people. One clear picture.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (error != null)
                Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(register ? 'Create account' : 'Sign in'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => register = !register),
                child: Text(
                  register
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Home extends StatefulWidget {
  final ExpenseStore store;
  final bool demo;
  const Home({super.key, required this.store, this.demo = false});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, dynamic>? selected;
  late Stream<List<Map<String, dynamic>>> groupStream;
  late Stream<List<Map<String, dynamic>>> expenseStream;
  @override
  void initState() {
    super.initState();
    groupStream = widget.store.groups;
    expenseStream = widget.store.expenses(null);
  }

  void select(Map<String, dynamic>? group) => setState(() {
    selected = group;
    expenseStream = widget.store.expenses(group?['id']);
  });
  Future<void> createGroup() async {
    final name = TextEditingController(), emails = TextEditingController();
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Create a group'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Group name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emails,
                  decoration: const InputDecoration(
                    labelText: 'Member emails, separated by commas',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Members must sign up with these emails and verify them to access shared records.',
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final members = {
                        widget.store.user,
                        ...emails.text
                            .split(',')
                            .map((s) => s.trim().toLowerCase())
                            .where((s) => s.isNotEmpty),
                      }.toList();
                      if (name.text.trim().isEmpty ||
                          name.text.trim().length > 100 ||
                          members.length > 20 ||
                          members.length < 2 ||
                          members.any(
                            (s) =>
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(s),
                          )) {
                        update(
                          () => error = 'Enter a name (up to 100 characters) and 2–20 valid member emails, including yours.',
                        );
                        return;
                      }
                      update(() => saving = true);
                      try {
                        await widget.store.createGroup(
                          name.text.trim(),
                          members,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        update(() {
                          saving = false;
                          error = 'Could not create group. Verify your email and connection.';
                        });
                      }
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    emails.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('◉  Together'),
      actions: [
        if (widget.demo)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('DEMO • temporary data'),
          ),
        if (!widget.demo)
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => ExpenseDialog(store: widget.store, group: selected),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Add expense'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'A little clarity, every day.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Track your own spending or share the cost of life together.',
            ),
            if (!widget.demo &&
                !(FirebaseAuth.instance.currentUser?.emailVerified ?? false))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Check your inbox to verify your email before using shared groups.',
                      ),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.currentUser?.reload();
                          await FirebaseAuth.instance.currentUser?.getIdToken(
                            true,
                          );
                          if (mounted) setState(() {});
                        },
                        child: const Text('I have verified my email'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: groupStream,
              builder: (context, snapshot) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Personal'),
                        selected: selected == null,
                        onSelected: (_) => select(null),
                      ),
                      ...?snapshot.data?.map(
                        (g) => ChoiceChip(
                          label: Text(g['name']),
                          selected: selected?['id'] == g['id'],
                          onSelected: (_) => select(g),
                        ),
                      ),
                      ActionChip(
                        label: const Text('New group'),
                        avatar: const Icon(Icons.add, size: 18),
                        onPressed: createGroup,
                      ),
                    ],
                  ),
                  if (snapshot.hasError)
                    const Text(
                      'Groups unavailable. Check email verification, Firebase rules, and connection.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: expenseStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Could not load expenses. Check connection and permissions.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final expenses = snapshot.data!;
                final total = expenses.fold<int>(
                  0,
                  (sum, e) => sum + (e['cents'] as num).toInt(),
                );
                final members = selected == null
                    ? [widget.store.user]
                    : List<String>.from(selected!['members']);
                final net = balances(expenses, members);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: const Color(0xff163f38),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected?['name'] ?? 'Personal spending',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              money(total),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${expenses.length} expenses • USD • all time',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Group balances',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Positive balances are owed money; negative balances owe money.',
                      ),
                      ...net.entries.map(
                        (e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(e.key),
                          trailing: Text(money(e.value)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Expense history',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (expenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48),
                            SizedBox(height: 16),
                            Text('Start with your first expense.'),
                            Text(
                              'Coffee, groceries, or your next group adventure.',
                            ),
                          ],
                        ),
                      ),
                    ...expenses.map(
                      (e) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.receipt_outlined),
                          ),
                          title: Text(e['title']),
                          subtitle: Text(
                            '${e['category']} • ${(e['date'] as String).substring(0, 10)}\nPaid by ${e['payer']}',
                          ),
                          isThreeLine: true,
                          trailing: Text(money((e['cents'] as num).toInt())),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class ExpenseDialog extends StatefulWidget {
  final ExpenseStore store;
  final Map<String, dynamic>? group;
  const ExpenseDialog({super.key, required this.store, this.group});
  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  final title = TextEditingController(), amount = TextEditingController();
  late final List<String> members;
  late final Map<String, TextEditingController> custom;
  late String payer;
  String category = 'Food', split = 'Equal';
  DateTime date = DateTime.now();
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    members = widget.group == null
        ? [widget.store.user]
        : List<String>.from(widget.group!['members']);
    payer = widget.store.user;
    custom = {for (final m in members) m: TextEditingController(text: '0.00')};
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    for (final c in custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    try {
      final cents = parseMoney(amount.text);
      if (title.text.trim().isEmpty || title.text.trim().length > 200) {
        throw const FormatException(
          'Add an expense title (up to 200 characters).',
        );
      }
      final shares = split == 'Equal'
          ? equalSplit(cents, members)
          : {
              for (final m in members)
                m:
                    custom[m]!.text.trim() == '0' ||
                        custom[m]!.text.trim() == '0.00'
                    ? 0
                    : parseMoney(custom[m]!.text),
            };
      if (shares.values.fold<int>(0, (a, b) => a + b) != cents) {
        throw const FormatException('Custom shares must add up to the total.');
      }
      setState(() {
        saving = true;
        error = null;
      });
      await widget.store.addExpense(widget.group?['id'], {
        'title': title.text.trim(),
        'cents': cents,
        'payer': payer,
        'shares': shares,
        'category': category,
        'date': date.toIso8601String(),
      });
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save. Check connection and permissions.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.group == null ? 'Add personal expense' : 'Add shared expense',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'What was it for?'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (USD)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                'Food',
                'Groceries',
                'Transport',
                'Home',
                'Travel',
                'Shopping',
                'Other',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (s) => category = s!,
            ),
            TextButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => date = d);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(date.toIso8601String().substring(0, 10)),
            ),
            if (widget.group != null) ...[
              DropdownButtonFormField<String>(
                initialValue: payer,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: members
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (m) => payer = m!,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Equal', label: Text('Equal')),
                  ButtonSegment(value: 'Custom', label: Text('Custom')),
                ],
                selected: {split},
                onSelectionChanged: (s) => setState(() => split = s.first),
              ),
              if (split == 'Custom')
                ...members.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: custom[m],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: '$m (USD)'),
                    ),
                  ),
                ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save expense'),
      ),
    ],
  );
}
