import 'package:flutter/material.dart';
import '../controllers/alarm_controller.dart';
import '../data/db_helper.dart';

class HostelHubScreen extends StatefulWidget {
  final AlarmController controller;

  const HostelHubScreen({
    super.key,
    required this.controller,
  });

  @override
  State<HostelHubScreen> createState() => _HostelHubScreenState();
}

class _HostelHubScreenState extends State<HostelHubScreen> {
  List<Map<String, dynamic>> _pairedDevices = [];
  bool _isLoadingPeers = true;

  @override
  void initState() {
    super.initState();
    widget.controller.loadAuditLogs();
    widget.controller.loadActiveRoom();
    _loadPairedPeers();
  }

  Future<void> _loadPairedPeers() async {
    final devices = await DBHelper.instance.getPairedDevices();
    if (mounted) {
      setState(() {
        _pairedDevices = devices;
        _isLoadingPeers = false;
      });
    }
  }

  Future<void> _showCreateRoomDialog() async {
    final roomNameController = TextEditingController(text: 'B204');
    final hostCodeController = TextEditingController(text: '748291');

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16181F),
          title: const Row(
            children: [
              Icon(Icons.meeting_room_outlined, color: Color(0xFF0A84FF)),
              SizedBox(width: 10),
              Text(
                'Create Hostel Room',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Room Identifier',
                  labelStyle: TextStyle(color: Color(0xFF8E93A4)),
                  hintText: 'e.g. B204 or Block-A-302',
                  hintStyle: TextStyle(color: Color(0xFF4A4E5D)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF282B37)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF0A84FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hostCodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, letterSpacing: 3.0),
                decoration: const InputDecoration(
                  labelText: '6-Digit Room Host Code',
                  labelStyle: TextStyle(color: Color(0xFF8E93A4)),
                  hintText: '6-digit PIN',
                  counterStyle: TextStyle(color: Color(0xFF8E93A4)),
                  hintStyle: TextStyle(color: Color(0xFF4A4E5D)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF282B37)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF0A84FF)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E93A4))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final roomName = roomNameController.text.trim();
                final hostCode = hostCodeController.text.trim();
                if (roomName.isNotEmpty && hostCode.length == 6) {
                  await widget.controller.createRoom(roomName, hostCode);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hostel Hub room "$roomName" active.'),
                        backgroundColor: const Color(0xFF30D158),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Room'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearAuditLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16181F),
          title: const Text(
            'Clear Audit Ledger?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This will permanently delete all logged deactivation receipts from the local ledger.',
            style: TextStyle(color: Color(0xFF8E93A4)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E93A4))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.controller.clearAuditLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audit ledger cleared.'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final activeRoom = widget.controller.activeRoom;
        final auditLogs = widget.controller.auditLogs;
        final connectedCount = widget.controller.socketHub.connectedClientCount;

        return Scaffold(
          backgroundColor: const Color(0xFF0C0D12),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0C0D12),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'HOSTEL HUB LEDGER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFF3B30)),
                tooltip: 'Clear Ledger',
                onPressed: auditLogs.isEmpty ? null : _confirmClearAuditLogs,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // COMPONENT A: ACTIVE ROOM NODE
                // ==========================================
                _buildActiveRoomNodeCard(activeRoom, connectedCount),
                const SizedBox(height: 16),

                // ==========================================
                // PEER NODES STATUS (Tethered / Authorized)
                // ==========================================
                _buildConnectedPeersCard(connectedCount),
                const SizedBox(height: 24),

                // ==========================================
                // COMPONENT B: THE ACTION LEDGER RECEIPT LIST
                // ==========================================
                _buildLedgerHeader(auditLogs.length),
                const SizedBox(height: 12),
                _buildActionLedgerReceiptList(auditLogs),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveRoomNodeCard(Map<String, dynamic>? activeRoom, int connectedCount) {
    final roomName = activeRoom?['room_name'] as String? ?? 'B204';
    final hostCode = activeRoom?['host_code'] as String? ?? '748291';
    final hasCustomRoom = activeRoom != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16181F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0A84FF).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A84FF).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active Room Badge (Component A Specification)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0A84FF),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🏢 ROOM: ',
                      style: TextStyle(
                        color: Color(0xFF0A84FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      roomName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, color: Color(0xFF8E93A4), size: 24),
                tooltip: hasCustomRoom ? 'Edit Room' : 'Configure Room',
                onPressed: _showCreateRoomDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HOST CONNECTION CODE',
                      style: TextStyle(
                        color: Color(0xFF8E93A4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hostCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: connectedCount > 0
                      ? const Color(0xFF30D158).withValues(alpha: 0.15)
                      : const Color(0xFF4A4E5D).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: connectedCount > 0
                        ? const Color(0xFF30D158)
                        : const Color(0xFF4A4E5D),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connectedCount > 0
                            ? const Color(0xFF30D158)
                            : const Color(0xFF8E93A4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$connectedCount Tethered',
                      style: TextStyle(
                        color: connectedCount > 0
                            ? const Color(0xFF30D158)
                            : const Color(0xFF8E93A4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedPeersCard(int connectedCount) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16181F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282B37)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ROOMMATE PEER NODES',
                style: TextStyle(
                  color: Color(0xFF8E93A4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${_pairedDevices.length} Authorized',
                style: const TextStyle(
                  color: Color(0xFF5D6273),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingPeers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
              ),
            )
          else if (_pairedDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1F222E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF8E93A4), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No peer devices authorized yet. Pair with roommates via Peer Authorization.',
                      style: TextStyle(color: Color(0xFF8E93A4), fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pairedDevices.map((device) {
                final friendName = device['friend_name'] as String? ?? 'Peer';
                final isAuthorized = device['is_authorized'] == 1;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F222E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAuthorized
                          ? const Color(0xFF30D158).withValues(alpha: 0.4)
                          : const Color(0xFF4A4E5D),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: isAuthorized
                            ? const Color(0xFF30D158)
                            : const Color(0xFF8E93A4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        friendName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLedgerHeader(int receiptCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.history_edu, color: Color(0xFFFF9500), size: 20),
            SizedBox(width: 8),
            Text(
              'ACTION LEDGER RECEIPTS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1F222E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$receiptCount records',
            style: const TextStyle(
              color: Color(0xFF8E93A4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionLedgerReceiptList(List<Map<String, dynamic>> auditLogs) {
    if (auditLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF16181F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF282B37)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 54,
              color: Color(0xFF4A4E5D),
            ),
            SizedBox(height: 16),
            Text(
              'No Deactivation Receipts',
              style: TextStyle(
                color: Color(0xFF8E93A4),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Deactivation & snooze events will be logged here with actor attribution.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF5D6273),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: auditLogs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = auditLogs[index];
        final actor = log['actor_name'] as String? ?? 'Unknown';
        final action = (log['action_type'] as String? ?? 'DISMISS').toUpperCase();
        final timestamp = log['timestamp'] as String? ?? '--:--';
        final isDismiss = action.contains('DISMISS');

        // Specification receipt format:
        // "• 07:02 AM - Alarm Silenced Remotely by Karthi."
        // "• 06:45 AM - Snoozed 5 mins by Rahul."
        final actionText = isDismiss
            ? 'Alarm Silenced Remotely by $actor.'
            : 'Snoozed Remotely by $actor.';
        final receiptLine = '• $timestamp - $actionText';

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16181F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDismiss
                  ? const Color(0xFFFF3B30).withValues(alpha: 0.3)
                  : const Color(0xFFFF9500).withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDismiss
                      ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                      : const Color(0xFFFF9500).withValues(alpha: 0.15),
                ),
                child: Icon(
                  isDismiss ? Icons.alarm_off : Icons.snooze,
                  size: 18,
                  color: isDismiss ? const Color(0xFFFF3B30) : const Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receiptLine,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          action,
                          style: TextStyle(
                            color: isDismiss
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFFFF9500),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Actor: $actor',
                          style: const TextStyle(
                            color: Color(0xFF8E93A4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
