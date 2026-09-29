import 'package:flutter/material.dart';
import 'controllers/alarm_controller.dart';
import 'screens/escalation_overlay.dart';
import 'screens/eye_clock_widget.dart';
import 'screens/hostel_hub_screen.dart';
import 'screens/network_hud_widget.dart';
import 'screens/pairing_screen.dart';
import 'screens/splash_anim_screen.dart';
import 'services/alarm_service.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const SplashAnimScreen(),
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
  int _selectedTabIndex = 0;

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
            colorScheme: const ColorScheme.light(
              primary: AppTheme.starkBlack,
              onPrimary: Colors.white,
              surface: AppTheme.cardWhite,
              onSurface: AppTheme.starkBlack,
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
          backgroundColor: AppTheme.creamCanvas,
          appBar: AppBar(
            title: const Text('SHUT IT OFF'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2.0),
              child: Container(
                color: AppTheme.starkBlack,
                height: 2.0,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.meeting_room_outlined, color: AppTheme.starkBlack),
                tooltip: 'Hostel Hub Ledger',
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 2;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.people_outline, color: AppTheme.starkBlack),
                tooltip: 'Peer Authorization',
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 1;
                  });
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (_alarmController.localSystemAlarmTime != null)
                    _buildSystemAlarmConflictBanner(_alarmController.localSystemAlarmTime!),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        // ========================================================
                        // VIEW PANEL A: THE ALARM CONFIGURATION SCHEDULER VIEW
                        // ========================================================
                        _buildSchedulerView(),

                        // ========================================================
                        // VIEW PANEL B: THE P2P HANDSHAKE EXCHANGE INPUT
                        // ========================================================
                        PairingScreen(
                          isEmbedded: true,
                          controller: _alarmController,
                        ),

                        // ========================================================
                        // VIEW PANEL C: THE MULTI-PEER HOSTEL HUB TIMELINE MONITOR
                        // ========================================================
                        HostelHubScreen(
                          controller: _alarmController,
                          isEmbedded: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Chronological Escalation Overlay
              if (_alarmController.isEscalated)
                EscalationOverlay(
                  friendName: _alarmController.escalatedFriendName ?? 'Your Roommate',
                  onWakeHim: () {
                    _alarmController.sendForceWakeCommand();
                  },
                  onDismiss: () {
                    _alarmController.triggerRemoteDismiss(
                      _alarmController.activeRingingAlarmId ?? 0,
                    );
                  },
                ),

              // Aggressive Heads-Up Firing Overlay
              if (_alarmController.isCurrentlyRinging)
                _buildAggressiveRingingOverlay(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.starkBlack, width: 2.0),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedTabIndex,
              onTap: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              backgroundColor: AppTheme.creamCanvas,
              selectedItemColor: AppTheme.starkBlack,
              unselectedItemColor: AppTheme.textMuted,
              selectedLabelStyle: const TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.alarm),
                  activeIcon: Icon(Icons.alarm_on),
                  label: 'ALARMS',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.handshake_outlined),
                  activeIcon: Icon(Icons.handshake),
                  label: 'HANDSHAKE',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.domain_outlined),
                  activeIcon: Icon(Icons.domain),
                  label: 'HOSTEL HUB',
                ),
              ],
            ),
          ),
          floatingActionButton: _selectedTabIndex == 0
              ? FloatingActionButton(
                  backgroundColor: AppTheme.starkBlack,
                  foregroundColor: Colors.white,
                  onPressed: _pickAndAddAlarm,
                  tooltip: 'Add Alarm',
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    side: BorderSide(color: AppTheme.starkBlack, width: 2.0),
                  ),
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSystemAlarmConflictBanner(String alarmTime) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.starkBlack, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.starkBlack,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.alarmOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.starkBlack, width: 1.5),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppTheme.alarmOrange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '⚠️ CRITICAL CONFLICT: You have an active system alarm scheduled at $alarmTime. Delete it immediately to grant remote management rights!',
              style: const TextStyle(
                fontFamily: 'serif',
                color: AppTheme.starkBlack,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulerView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Step 2 Requirement: Interface Glow Node (Eye-Clock Widget)
          EyeClockWidget(
            controller: _alarmController,
          ),

          // Network Connection HUD
          NetworkHudWidget(
            controller: _alarmController,
            onScanTap: () {
              _alarmController.discoveryService.startBrowsing();
            },
          ),

          // Custom Alarms List
          _buildAlarmList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAlarmList() {
    final alarms = _alarmController.alarms;

    if (alarms.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: AppTheme.panelDecoration(),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alarm_off_outlined,
              size: 58,
              color: AppTheme.textMuted,
            ),
            SizedBox(height: 14),
            Text(
              'No Alarms Set',
              style: TextStyle(
                fontFamily: 'serif',
                color: AppTheme.starkBlack,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tap + below to create a persistent local alarm',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              color: AppTheme.alarmOrange,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.starkBlack, width: 2.0),
            ),
            child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
          ),
          onDismissed: (_) {
            _alarmController.deleteAlarm(id);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: AppTheme.panelDecoration(
              color: isEnabled ? AppTheme.cardWhite : AppTheme.panelCream,
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
                        fontFamily: 'serif',
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: isEnabled ? AppTheme.starkBlack : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? AppTheme.neonCyan.withValues(alpha: 0.25)
                            : AppTheme.textLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isEnabled ? AppTheme.starkBlack : AppTheme.textMuted,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        isEnabled ? 'ACTIVE SCHEDULE' : 'DISABLED',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isEnabled ? AppTheme.starkBlack : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Switch(
                      value: isEnabled,
                      activeThumbColor: AppTheme.starkBlack,
                      activeTrackColor: AppTheme.neonCyan.withValues(alpha: 0.5),
                      inactiveThumbColor: AppTheme.textMuted,
                      inactiveTrackColor: AppTheme.panelCream,
                      onChanged: (value) {
                        _alarmController.toggleAlarm(id, value);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.alarmOrange),
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
        color: AppTheme.creamCanvas,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.alarmOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.starkBlack, width: 3.0),
                      boxShadow: const [
                        BoxShadow(
                          color: AppTheme.starkBlack,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      size: 54,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'SHUT IT OFF NOW',
                    style: TextStyle(
                      fontFamily: 'serif',
                      color: AppTheme.alarmOrange,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: AppTheme.panelDecoration(
                      color: AppTheme.cardWhite,
                    ),
                    child: Text(
                      displayTime,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        color: AppTheme.starkBlack,
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _alarmController.ringingDurationSeconds >= 60
                          ? AppTheme.alarmOrange
                          : AppTheme.panelCream,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                    ),
                    child: Text(
                      _alarmController.ringingDurationSeconds >= 60
                          ? '⚠️ ESCALATED TO ROOMMATES (${_alarmController.ringingDurationSeconds}s)'
                          : 'Ringing: ${_alarmController.ringingDurationSeconds}s (Escalates at 60s)',
                      style: TextStyle(
                        fontFamily: 'serif',
                        color: _alarmController.ringingDurationSeconds >= 60
                            ? Colors.white
                            : AppTheme.starkBlack,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.starkBlack,
                          width: 2.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: AppTheme.cardWhite,
                        elevation: 0,
                      ),
                      onPressed: () {
                        _alarmController.snoozeLocalAlarm(activeId, 5);
                      },
                      child: const Text(
                        '[SNOOZE] (5 MIN)',
                        style: TextStyle(
                          fontFamily: 'serif',
                          color: AppTheme.starkBlack,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
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
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppTheme.starkBlack,
              width: 2.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.starkBlack,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: (_dragPosition + _thumbWidth + 4).clamp(0.0, constraints.maxWidth),
                height: _barHeight,
                decoration: BoxDecoration(
                  color: AppTheme.alarmOrange.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              const Center(
                child: Text(
                  '[TURN OFF]  >>>',
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: AppTheme.starkBlack,
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
                    decoration: BoxDecoration(
                      color: AppTheme.alarmOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.starkBlack, width: 2.0),
                      boxShadow: const [
                        BoxShadow(
                          color: AppTheme.starkBlack,
                          offset: Offset(2, 2),
                          blurRadius: 0,
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
