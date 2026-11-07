import 'dart:async';

import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

/// Small glass banner shown while the database can't be reached. It waits
/// ~2 seconds before appearing so it doesn't flash during start-up or a
/// brief network blip, and hides as soon as the connection is back.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});
  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  static const _delay = Duration(seconds: 2);
  Timer? _timer;
  bool _visible = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync(bool offline) {
    if (offline && !_visible && _timer == null) {
      _timer = Timer(_delay, () {
        _timer = null;
        if (!mounted) return;
        final st = context.storeRead;
        if (st.offline || st.link == 'error' || st.link == 'signed-out') setState(() => _visible = true);
      });
    } else if (!offline) {
      _timer?.cancel();
      _timer = null;
      if (_visible) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _visible = false) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.store;
    final pb = context.pb;
    final refused = s.link == 'error' || s.link == 'signed-out';
    _sync(s.offline || refused);
    final pending = s.pendingWrites;
    final c = refused ? pb.danger : pb.modeMaintenance;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !_visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 8),
              child: Semantics(
                liveRegion: true,
                child: Glass(
                  radius: 18,
                  blur: 20,
                  tint: c,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    PIcon(refused ? 'shield' : 'wifi', size: 17, color: c),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(refused ? "Can't connect to the database" : 'Offline — showing last saved data',
                            style: body(12, weight: FontWeight.w600, color: pb.text)),
                        const SizedBox(height: 2),
                        Text(
                          refused
                              ? (s.linkError ?? 'The database refused the connection.')
                              : pending == 0
                                  ? 'Commands will send when back online.'
                                  : '$pending command${pending == 1 ? '' : 's'} queued · will send when back online.',
                          style: body(11, color: pb.muted),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}
