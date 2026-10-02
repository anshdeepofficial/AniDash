import 'package:ani_dash/core/services/admin_broadcast_service.dart';
import 'package:ani_dash/core/services/developer_access_service.dart';
import 'package:ani_dash/core/utils/env_loader.dart';
import 'package:ani_dash/shared/auth/providers/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _pin = TextEditingController();
  final _service = const AdminBroadcastService();
  final _accessService = const DeveloperAccessService();
  Map<String, int>? _stats;
  bool _loading = false;
  bool _checkingAccess = true;
  bool _unlocked = false;
  bool _blocked = false;
  int _remainingAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAccess());
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _pin.dispose();
    super.dispose();
  }

  String? get _token => ref.read(authProvider).anilistAccessToken;

  bool get _isDeveloper =>
      ref.read(authProvider).anilistUser?.id.toString() == ADMIN_ANILIST_ID;

  Future<void> _initializeAccess() async {
    final blocked = await _accessService.isBlocked();
    final unlocked = await _accessService.isUnlocked();
    final remaining = await _accessService.remainingAttempts();
    if (!mounted) return;
    setState(() {
      _blocked = blocked;
      _unlocked = unlocked && !blocked;
      _remainingAttempts = remaining;
      _checkingAccess = false;
    });
    if (_unlocked) await _loadStats();
  }

  Future<void> _unlock() async {
    final token = _token;
    if (token == null || _pin.text.length != 4) return;
    setState(() => _loading = true);
    try {
      final success = await _accessService.verify(
        accessToken: token,
        pin: _pin.text,
      );
      if (!mounted) return;
      setState(() => _unlocked = success);
      if (success) await _loadStats();
    } catch (error) {
      final remaining = await _accessService.remainingAttempts();
      final blocked = await _accessService.isBlocked();
      if (!mounted) return;
      setState(() {
        _remainingAttempts = remaining;
        _blocked = blocked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is DeveloperVerificationUnavailable
                ? error.toString()
                : blocked
                ? 'Developer access disabled on this installation.'
                : '${error.toString().replaceFirst('Exception: ', '')}. $remaining attempts left.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    final token = _token;
    final pin = await _accessService.savedPin();
    if (token == null || pin == null) return;
    try {
      final stats = await _service.loadStats(token, pin);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _send() async {
    final token = _token;
    final pin = await _accessService.savedPin();
    if (token == null ||
        pin == null ||
        _title.text.trim().isEmpty ||
        _message.text.trim().isEmpty) {
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.send(
        accessToken: token,
        developerPin: pin,
        title: _title.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement sent to all users.')),
      );
      _title.clear();
      _message.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!_isDeveloper || _blocked) {
      return const Scaffold(body: Center(child: Text('Access unavailable')));
    }
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Developer Verification')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Iconsax.security_safe, size: 56),
            const SizedBox(height: 20),
            const Text(
              'Enter your one-time four-digit developer PIN.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Developer PIN',
                helperText: '$_remainingAttempts attempts remaining',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _unlock,
              child: const Text('Verify'),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Broadcast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Installed devices',
                  value: _stats?['totalDevices'],
                  icon: Iconsax.mobile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Push subscribers',
                  value: _stats?['subscribedDevices'],
                  icon: Iconsax.notification,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Active today',
                  value: _stats?['activeToday'],
                  icon: Iconsax.activity,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Active 7 days',
                  value: _stats?['active7Days'],
                  icon: Iconsax.calendar_1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Active 30 days',
                  value: _stats?['active30Days'],
                  icon: Iconsax.chart_1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Activity totals are anonymous aggregates. Names and watch history are never included.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Notification title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            maxLength: 1000,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Message for all users',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _send,
            icon:
                _loading
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Iconsax.send_1),
            label: const Text('Send to all installed apps'),
          ),
          const SizedBox(height: 12),
          Text(
            'Only your approved AniList account can open this page or send messages.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              value?.toString() ?? '—',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
