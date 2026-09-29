import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/permission_controller.dart';
import '../models/pairing_handshake.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

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
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    if (inputCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(inputCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit connection code.'),
          backgroundColor: Color(0xFFD32F2F),
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
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      // High-contrast, minimalist light theme specification
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF111315),
          secondary: Color(0xFFD32F2F),
          surface: Colors.white,
          onSurface: Color(0xFF111315),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111315),
          elevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF111315),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PEER AUTHORIZATION'),
        ),
        body: ListenableBuilder(
          listenable: _permissionController,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildScreenNodeA(),
                  const SizedBox(height: 24),
                  _buildScreenNodeB(),
                  const SizedBox(height: 24),
                  _buildScreenNodeC(),
                  const SizedBox(height: 28),
                  _buildAuthorizeButton(),
                  const SizedBox(height: 36),
                  _buildAuthorizedDevicesList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Screen Node A: "My Connection Code"
  Widget _buildScreenNodeA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E4E8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MY CONNECTION CODE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFF5F6368),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF111315)),
                onPressed: _regenerateMyCode,
                tooltip: 'Generate New Code',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD8DCE0)),
            ),
            child: Text(
              _myConnectionCode,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 8.0,
                fontFamily: 'monospace',
                color: Color(0xFF111315),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Share this 6-digit code with your roommate to bind devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5F6368),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Screen Node B: "Enter Friend's Code"
  Widget _buildScreenNodeB() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E4E8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ENTER FRIEND'S CODE",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFF5F6368),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _friendNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: "Friend / Roommate Name",
              labelStyle: const TextStyle(color: Color(0xFF5F6368)),
              hintText: "e.g. Alex",
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD8DCE0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF111315), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              color: Color(0xFF111315),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: "000000",
              hintStyle: const TextStyle(
                color: Color(0xFFB0B5BA),
                letterSpacing: 6.0,
              ),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD8DCE0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF111315), width: 2),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E4E8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GRANULAR PERMISSIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFF5F6368),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _allowTurnOff,
            activeColor: const Color(0xFF111315),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '[Allow Turn Off]',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF111315),
              ),
            ),
            subtitle: const Text(
              'Permit peer to silence and turn off ringing alarms',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
            ),
            onChanged: (val) {
              setState(() {
                _allowTurnOff = val ?? false;
              });
            },
          ),
          const Divider(color: Color(0xFFE2E4E8)),
          CheckboxListTile(
            value: _allowSnooze,
            activeColor: const Color(0xFF111315),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '[Allow Snooze]',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF111315),
              ),
            ),
            subtitle: const Text(
              'Permit peer to snooze ringing alarms for 5 minutes',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
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
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111315),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: _authorizeFriend,
        child: const Text(
          'CONFIRM AUTHORIZATION',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 12),
        if (devices.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E4E8)),
            ),
            child: const Text(
              'No peer devices authorized yet.',
              style: TextStyle(color: Color(0xFF8E93A4), fontSize: 14),
            ),
          )
        else
          ...devices.map((device) {
            final id = device.id ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: device.isAuthorized
                      ? const Color(0xFF2E7D32).withAlpha(60)
                      : const Color(0xFFE2E4E8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            device.friendName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF111315),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: device.isAuthorized
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              device.isAuthorized ? 'AUTHORIZED' : 'REVOKED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: device.isAuthorized
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
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
                          fontSize: 12,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                    ],
                  ),
                  if (device.isAuthorized)
                    TextButton(
                      onPressed: () => _permissionController.revokeDevice(id),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD32F2F),
                      ),
                      child: const Text(
                        'REVOKE',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
