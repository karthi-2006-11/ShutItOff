import 'package:flutter/material.dart';
import '../controllers/alarm_controller.dart';
import '../data/db_helper.dart';
import '../theme/app_theme.dart';

class HostelHubScreen extends StatefulWidget {
  final AlarmController controller;
  final bool isEmbedded;

  const HostelHubScreen({
    super.key,
    required this.controller,
    this.isEmbedded = false,
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
          backgroundColor: AppTheme.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.starkBlack, width: 2.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.meeting_room_outlined, color: AppTheme.starkBlack),
              SizedBox(width: 10),
              Text(
                'Configure Hostel Room',
                style: AppTheme.slabTitle,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNameController,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.starkBlack),
                decoration: const InputDecoration(
                  labelText: 'Room Identifier',
                  hintText: 'e.g. B204 or Block-A-302',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hostCodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                  color: AppTheme.starkBlack,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  labelText: '6-Digit Room Host Code',
                  counterText: '',
                  hintText: '6-digit PIN',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.starkBlack,
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
                        backgroundColor: AppTheme.successGreen,
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
          backgroundColor: AppTheme.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.starkBlack, width: 2.5),
          ),
          title: const Text(
            'Clear Audit Ledger?',
            style: AppTheme.slabTitle,
          ),
          content: const Text(
            'This will permanently delete all logged deactivation receipts from the local ledger.',
            style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.alarmOrange,
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
            backgroundColor: AppTheme.alarmOrange,
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

        final bodyContent = SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              const SizedBox(height: 20),

              // ==========================================
              // COMPONENT B: THE ACTION LEDGER RECEIPT LIST
              // ==========================================
              _buildLedgerHeader(auditLogs.length),
              const SizedBox(height: 12),
              _buildActionLedgerReceiptList(auditLogs),
            ],
          ),
        );

        if (widget.isEmbedded) {
          return Container(
            color: AppTheme.creamCanvas,
            child: bodyContent,
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.creamCanvas,
          appBar: AppBar(
            backgroundColor: AppTheme.creamCanvas,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.starkBlack),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'HOSTEL HUB LEDGER',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.alarmOrange),
                tooltip: 'Clear Ledger',
                onPressed: auditLogs.isEmpty ? null : _confirmClearAuditLogs,
              ),
            ],
          ),
          body: bodyContent,
        );
      },
    );
  }

  Widget _buildActiveRoomNodeCard(Map<String, dynamic>? activeRoom, int connectedCount) {
    final roomName = activeRoom?['room_name'] as String? ?? 'B204';
    final hostCode = activeRoom?['host_code'] as String? ?? '748291';
    final hasCustomRoom = activeRoom != null;

    return Container(
      decoration: AppTheme.panelDecoration(color: AppTheme.cardWhite),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active Room Badge (Component A Specification)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.starkBlack,
                    width: 2.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🏢 ROOM: ',
                      style: TextStyle(
                        fontFamily: 'serif',
                        color: AppTheme.starkBlack,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      roomName.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'serif',
                        color: AppTheme.starkBlack,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, color: AppTheme.starkBlack, size: 26),
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
                        fontFamily: 'serif',
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hostCode,
                      style: const TextStyle(
                        color: AppTheme.starkBlack,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
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
                      ? AppTheme.neonCyan.withValues(alpha: 0.25)
                      : AppTheme.panelCream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.starkBlack,
                    width: 1.5,
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
                            ? AppTheme.successGreen
                            : AppTheme.textMuted,
                        border: Border.all(color: AppTheme.starkBlack, width: 1.0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$connectedCount Tethered',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        color: AppTheme.starkBlack,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
      decoration: AppTheme.panelDecoration(color: AppTheme.cardWhite),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ROOMMATE PEER NODES',
                style: AppTheme.slabLabel,
              ),
              Text(
                '${_pairedDevices.length} Authorized',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingPeers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppTheme.starkBlack),
              ),
            )
          else if (_pairedDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.creamCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.starkBlack, width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.textMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No peer devices authorized yet. Pair with roommates via Peer Authorization.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
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
                    color: isAuthorized
                        ? AppTheme.neonCyan.withValues(alpha: 0.2)
                        : AppTheme.creamCanvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.starkBlack,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: isAuthorized
                            ? AppTheme.starkBlack
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        friendName,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          color: AppTheme.starkBlack,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
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
            Icon(Icons.history_edu, color: AppTheme.starkBlack, size: 20),
            SizedBox(width: 8),
            Text(
              'ACTION LEDGER RECEIPTS',
              style: TextStyle(
                fontFamily: 'serif',
                color: AppTheme.starkBlack,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.panelCream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.starkBlack, width: 1.2),
          ),
          child: Text(
            '$receiptCount records',
            style: const TextStyle(
              fontFamily: 'serif',
              color: AppTheme.starkBlack,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionLedgerReceiptList(List<Map<String, dynamic>> auditLogs) {
    if (auditLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: AppTheme.panelDecoration(color: AppTheme.cardWhite),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 50,
              color: AppTheme.textLight,
            ),
            SizedBox(height: 14),
            Text(
              'No Deactivation Receipts',
              style: TextStyle(
                fontFamily: 'serif',
                color: AppTheme.starkBlack,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Deactivation & snooze events will be logged here with actor attribution.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = auditLogs[index];
        final actor = log['actor_name'] as String? ?? 'Unknown';
        final action = (log['action_type'] as String? ?? 'DISMISS').toUpperCase();
        final timestamp = log['timestamp'] as String? ?? '--:--';
        final isDismiss = action.contains('DISMISS');

        // Specification receipt format:
        // "• 07:02 AM - Alarm Silenced Remotely by Karthi."
        // "• 06:45 AM - Snoozed Remotely by Rahul."
        final actionText = isDismiss
            ? 'Alarm Silenced Remotely by $actor.'
            : 'Snoozed Remotely by $actor.';
        final receiptLine = '• $timestamp - $actionText';

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.starkBlack,
              width: 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.starkBlack,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
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
                      ? AppTheme.alarmOrange.withValues(alpha: 0.2)
                      : AppTheme.warningAmber.withValues(alpha: 0.2),
                  border: Border.all(
                    color: isDismiss ? AppTheme.alarmOrange : AppTheme.warningAmber,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isDismiss ? Icons.alarm_off : Icons.snooze,
                  size: 18,
                  color: isDismiss ? AppTheme.alarmOrange : AppTheme.warningAmber,
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
                        fontFamily: 'serif',
                        color: AppTheme.starkBlack,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          action,
                          style: TextStyle(
                            fontFamily: 'serif',
                            color: isDismiss ? AppTheme.alarmOrange : AppTheme.warningAmber,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Actor: $actor',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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
