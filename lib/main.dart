import 'package:flutter/material.dart';
import 'controllers/alarm_controller.dart';
import 'services/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.initialize();
  runApp(const ShutItOffApp());
}

class ShutItOffApp extends StatelessWidget {
  const ShutItOffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShutItOff',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C0D12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF3B30),
          secondary: Color(0xFF30D158),
          surface: Color(0xFF16181F),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C0D12),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        useMaterial3: true,
      ),
      home: const AlarmHomeScreen(),
    );
  }
}

class AlarmHomeScreen extends StatefulWidget {
  const AlarmHomeScreen({super.key});

  @override
  State<AlarmHomeScreen> createState() => _AlarmHomeScreenState();
}

class _AlarmHomeScreenState extends State<AlarmHomeScreen> {
  final AlarmController _alarmController = AlarmController();

  @override
  void initState() {
    super.initState();
    _alarmController.initialize();
  }

  @override
  void dispose() {
    _alarmController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAddAlarm() async {
    final nowTime = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: nowTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF3B30),
              onPrimary: Colors.white,
              surface: Color(0xFF1F222E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      final hour = pickedTime.hour.toString().padLeft(2, '0');
      final minute = pickedTime.minute.toString().padLeft(2, '0');
      final formattedTime = '$hour:$minute';
      await _alarmController.addAlarm(formattedTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _alarmController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('SHUT IT OFF'),
          ),
          body: Stack(
            children: [
              _buildAlarmList(),
              if (_alarmController.isCurrentlyRinging)
                _buildAggressiveRingingOverlay(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFFFF3B30),
            foregroundColor: Colors.white,
            onPressed: _pickAndAddAlarm,
            tooltip: 'Add Alarm',
            child: const Icon(Icons.add, size: 28),
          ),
        );
      },
    );
  }

  Widget _buildAlarmList() {
    final alarms = _alarmController.alarms;

    if (alarms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alarm_off_outlined,
              size: 72,
              color: Color(0xFF4A4E5D),
            ),
            SizedBox(height: 16),
            Text(
              'No Alarms Set',
              style: TextStyle(
                color: Color(0xFF8E93A4),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap + to create a persistent alarm',
              style: TextStyle(
                color: Color(0xFF5D6273),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: alarms.length,
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        final id = alarm['id'] as int;
        final timeString = alarm['alarm_time'] as String;
        final isEnabled = (alarm['is_enabled'] as int) == 1;

        return Dismissible(
          key: ValueKey(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_forever, color: Colors.white),
          ),
          onDismissed: (_) {
            _alarmController.deleteAlarm(id);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF161822),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEnabled
                    ? const Color(0xFFFF3B30).withAlpha(80)
                    : const Color(0xFF282B37),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isEnabled ? Colors.white : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEnabled ? 'Active' : 'Disabled',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isEnabled
                            ? const Color(0xFF30D158)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Switch(
                      value: isEnabled,
                      activeThumbColor: const Color(0xFFFF3B30),
                      activeTrackColor: const Color(0xFFFF3B30).withAlpha(100),
                      inactiveThumbColor: const Color(0xFF555A69),
                      inactiveTrackColor: const Color(0xFF222530),
                      onChanged: (value) {
                        _alarmController.toggleAlarm(id, value);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFF7A7F91)),
                      onPressed: () => _alarmController.deleteAlarm(id),
                      tooltip: 'Delete Alarm',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAggressiveRingingOverlay() {
    final activeId = _alarmController.activeRingingAlarmId ?? 0;
    final activeAlarm = _alarmController.alarms.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a?['id'] == activeId,
          orElse: () => null,
        );
    final displayTime = activeAlarm?['alarm_time'] as String? ?? 'WAKE UP';

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F0000).withAlpha(248),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                children: [
                  SizedBox(height: 20),
                  Icon(
                    Icons.notifications_active,
                    size: 80,
                    color: Color(0xFFFF3B30),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'SHUT IT OFF NOW',
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    displayTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Alarm is ringing continuously',
                    style: TextStyle(
                      color: Color(0xFFB0B3C0),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwipeToTurnOffBar(
                    onTurnOff: () {
                      _alarmController.turnOffLocalAlarm(activeId);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFFF9F0A),
                          width: 2.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        backgroundColor: const Color(0xFFFF9F0A).withAlpha(25),
                      ),
                      onPressed: () {
                        _alarmController.snoozeLocalAlarm(activeId, 5);
                      },
                      child: const Text(
                        '[SNOOZE] (5 MIN)',
                        style: TextStyle(
                          color: Color(0xFFFF9F0A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwipeToTurnOffBar extends StatefulWidget {
  final VoidCallback onTurnOff;

  const SwipeToTurnOffBar({super.key, required this.onTurnOff});

  @override
  State<SwipeToTurnOffBar> createState() => _SwipeToTurnOffBarState();
}

class _SwipeToTurnOffBarState extends State<SwipeToTurnOffBar> {
  double _dragPosition = 0.0;
  static const double _barHeight = 64.0;
  static const double _thumbWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - _thumbWidth - 8.0;

        return Container(
          width: constraints.maxWidth,
          height: _barHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1E0707),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFFFF3B30),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: (_dragPosition + _thumbWidth + 4).clamp(0.0, constraints.maxWidth),
                height: _barHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withAlpha(80),
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              const Center(
                child: Text(
                  '[TURN OFF]  >>>',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              Positioned(
                left: 4.0 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx)
                          .clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragPosition >= maxDrag * 0.75) {
                      widget.onTurnOff();
                    } else {
                      setState(() {
                        _dragPosition = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: _thumbWidth,
                    height: _barHeight - 8.0,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF3B30),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.power_settings_new,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
