import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/alarm_controller.dart';
import '../controllers/permission_controller.dart';
import '../models/pairing_handshake.dart';
import '../theme/app_theme.dart';

class PairingScreen extends StatefulWidget {
  final bool isEmbedded;
  final AlarmController? controller;

  const PairingScreen({
    super.key,
    this.isEmbedded = false,
    this.controller,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final PermissionController _permissionController = PermissionController();
  final TextEditingController _friendNameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  late String _myConnectionCode;
  bool _allowTurnOff = true;
  bool _allowSnooze = true;

  @override
  void initState() {
    super.initState();
    _myConnectionCode = generateHandshakeCode();
    _permissionController.loadPairedDevices();
  }

  @override
  void dispose() {
    _friendNameController.dispose();
    _codeController.dispose();
    _permissionController.dispose();
    super.dispose();
  }

  void _regenerateMyCode() {
    setState(() {
      _myConnectionCode = generateHandshakeCode();
    });
  }

  Future<void> _authorizeFriend() async {
    final friendName = _friendNameController.text.trim();
    final inputCode = _codeController.text.trim();

    if (friendName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your friend\'s name.'),
          backgroundColor: AppTheme.alarmOrange,
        ),
      );
      return;
    }

    if (inputCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(inputCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit connection code.'),
          backgroundColor: AppTheme.alarmOrange,
        ),
      );
      return;
    }

    final newSession = PairingSession(
      friendName: friendName,
      connectionCode: inputCode,
      isAuthorized: true,
      canTurnOff: _allowTurnOff,
      canSnooze: _allowSnooze,
    );

    await _permissionController.registerPairing(newSession);

    if (mounted) {
      _friendNameController.clear();
      _codeController.clear();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authorized "$friendName" successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _permissionController,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScreenNodeA(),
              const SizedBox(height: 18),
              _buildScreenNodeB(),
              const SizedBox(height: 18),
              _buildScreenNodeC(),
              const SizedBox(height: 22),
              _buildAuthorizeButton(),
              const SizedBox(height: 28),
              _buildAuthorizedDevicesList(),
            ],
          ),
        );
      },
    );

    if (widget.isEmbedded) {
      return Container(
        color: AppTheme.creamCanvas,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.creamCanvas,
      appBar: AppBar(
        title: const Text('PEER AUTHORIZATION'),
      ),
      body: content,
    );
  }

  /// Screen Node A: "My Connection Code"
  Widget _buildScreenNodeA() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MY CONNECTION CODE',
                style: AppTheme.slabLabel,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 22, color: AppTheme.starkBlack),
                onPressed: _regenerateMyCode,
                tooltip: 'Generate New Code',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.creamCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.starkBlack, width: 2.0),
            ),
            child: Text(
              _myConnectionCode,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 8.0,
                fontFamily: 'monospace',
                color: AppTheme.starkBlack,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Share this 6-digit code with your roommate to bind devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Screen Node B: "Enter Friend's Code"
  Widget _buildScreenNodeB() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ENTER FRIEND'S CODE",
            style: AppTheme.slabLabel,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _friendNameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.starkBlack,
            ),
            decoration: const InputDecoration(
              labelText: "Friend / Roommate Name",
              hintText: "e.g. Alex",
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 6.0,
              fontFamily: 'monospace',
              color: AppTheme.starkBlack,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: "000000",
              hintStyle: TextStyle(
                color: AppTheme.textLight,
                letterSpacing: 6.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen Node C: Granular Permission Checkboxes
  Widget _buildScreenNodeC() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GRANULAR PERMISSIONS',
            style: AppTheme.slabLabel,
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _allowTurnOff,
            activeColor: AppTheme.starkBlack,
            checkColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '[Allow Turn Off]',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.starkBlack,
              ),
            ),
            subtitle: const Text(
              'Permit peer to silence and turn off ringing alarms',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            onChanged: (val) {
              setState(() {
                _allowTurnOff = val ?? false;
              });
            },
          ),
          const Divider(color: Color(0xFFE2E4E8), height: 16),
          CheckboxListTile(
            value: _allowSnooze,
            activeColor: AppTheme.starkBlack,
            checkColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '[Allow Snooze]',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.starkBlack,
              ),
            ),
            subtitle: const Text(
              'Permit peer to snooze ringing alarms for 5 minutes',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            onChanged: (val) {
              setState(() {
                _allowSnooze = val ?? false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorizeButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.starkBlack,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.starkBlack, width: 2.0),
          ),
        ),
        onPressed: _authorizeFriend,
        child: const Text(
          'CONFIRM AUTHORIZATION',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorizedDevicesList() {
    final devices = _permissionController.pairedDevices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUTHORIZED PEERS',
          style: AppTheme.slabLabel,
        ),
        const SizedBox(height: 10),
        if (devices.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.starkBlack, width: 1.5),
            ),
            child: const Text(
              'No peer devices authorized yet.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...devices.map((device) {
            final id = device.id ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.starkBlack,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  device.friendName,
                                  style: const TextStyle(
                                    fontFamily: 'serif',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppTheme.starkBlack,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: device.isAuthorized
                                        ? AppTheme.neonCyan.withValues(alpha: 0.25)
                                        : AppTheme.alarmOrange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: device.isAuthorized
                                          ? AppTheme.starkBlack
                                          : AppTheme.alarmOrange,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    device.isAuthorized ? 'AUTHORIZED' : 'REVOKED',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: device.isAuthorized
                                          ? AppTheme.starkBlack
                                          : AppTheme.alarmOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code: ${device.connectionCode} • '
                              '${device.canTurnOff ? "TurnOff ✓" : "TurnOff ✗"} • '
                              '${device.canSnooze ? "Snooze ✓" : "Snooze ✗"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (device.isAuthorized)
                        OutlinedButton(
                          onPressed: () => _permissionController.revokeDevice(id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.alarmOrange,
                            side: const BorderSide(color: AppTheme.alarmOrange, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text(
                            'REVOKE',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (device.isAuthorized) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.creamCanvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '⏰ Next Alarm: ${widget.controller?.getNextPeerAlarmDisplay(device.friendName) ?? "06:00 AM"}',
                              style: const TextStyle(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: AppTheme.starkBlack,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              final alarmId = widget.controller?.getNextPeerAlarmId(device.friendName) ?? 1;
                              widget.controller?.sendPreemptiveSkipCommand(alarmId, actorName: device.friendName);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Dispatched [Skip Today] for ${device.friendName}\'s upcoming alarm.'),
                                  backgroundColor: AppTheme.alarmOrange,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.cardWhite,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                              ),
                              child: const Text(
                                '[Skip Today]',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: AppTheme.alarmOrange,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}
