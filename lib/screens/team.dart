import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// 17 · TIM · STATUS LIVE ANGGOTA
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String _query = '';
  MemberState? _filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = app.activeGroup;
    if (g == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Belum ada grup. Buat atau gabung grup dulu di tab GRUP.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.dim)),
        ),
      );
    }

    final shown = app.members
        .where((m) => m.sharesLocation)
        .where((m) => _filter == null || m.state == _filter)
        .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => b.gapM.compareTo(a.gapM));

    return ListView(
      padding: const EdgeInsets.fromLTRB(K.pad, 6, K.pad, 20),
      children: [
        Row(
          children: [
            Avatar(g.initials, size: 40, radius: 12),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: context.fg)),
                  Mono(
                      'RENTANG ${num1(app.spreadKm)} KM · ${app.live.length} LIVE',
                      size: 10),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(fontSize: 14, color: context.fg),
          decoration: InputDecoration(
            hintText: 'Cari nama anggota…',
            hintStyle: TextStyle(fontSize: 14, color: context.dim),
            filled: true,
            fillColor: context.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: K.orange, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          children: [
            Pill('SEMUA ${app.members.where((m) => m.sharesLocation).length}',
                size: 10,
                selected: _filter == null,
                selectedColor: K.orange,
                onTap: () => setState(() => _filter = null)),
            const SizedBox(width: 8),
            Pill('BERGERAK ${app.countByState(MemberState.moving)}',
                size: 10,
                selected: _filter == MemberState.moving,
                selectedColor: K.orange,
                onTap: () => setState(() => _filter = MemberState.moving)),
            const SizedBox(width: 8),
            Pill('JEDA ${app.countByState(MemberState.paused)}',
                size: 10,
                color: K.warningInk,
                selected: _filter == MemberState.paused,
                selectedColor: K.orange,
                onTap: () => setState(() => _filter = MemberState.paused)),
            const SizedBox(width: 8),
            Pill('OFF ${app.members.where((m) => !m.sharesLocation).length + app.countByState(MemberState.offline)}',
                size: 10,
                color: context.dim,
                selected: _filter == MemberState.offline,
                selectedColor: K.orange,
                onTap: () => setState(() => _filter = MemberState.offline)),
          ],
          ),
        ),
        const SizedBox(height: 14),
        L('TERLACAK · ${shown.length}'),
        const SizedBox(height: 10),
        for (final m in shown) ...[
          _MemberRow(m),
          const SizedBox(height: 10),
        ],
        if (app.hidden.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: context.card,
              border: Border.all(color: context.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
                '${app.hidden.map((m) => m.name).join(" & ")} mematikan berbagi lokasi. '
                'Mereka tetap bisa merekam rute sendiri.',
                style: TextStyle(fontSize: 12.5, height: 1.55, color: context.dim)),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(this.m);

  final Member m;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = m.isMe;
    final session = app.session;
    final gap = app.gapFromMe(m);
    final detail = switch (m.state) {
      MemberState.offline => 'sinyal hilang · terakhir ${fmtAgo(m.lastPing)}',
      _ when me && session != null =>
        '${num1(m.speedKmh)} km/j · merekam ${fmtClock(session.movingSec)}',
      _ when me => '${num1(m.speedKmh)} km/j · kamu',
      _ => '${num1(m.speedKmh)} km/j · '
          '${fmtGap(gap)} ${gap >= 0 ? "di depan" : "di belakang"}',
    };

    return Opacity(
      opacity: m.state == MemberState.offline ? .75 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: context.card,
          border: Border(
              left: BorderSide(
                  color: m.state == MemberState.offline
                      ? context.line
                      : (me ? K.orange : (m.state == MemberState.paused ? K.warning : K.success)),
                  width: 3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Avatar(m.initials, color: m.color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.fg)),
                      ),
                      const SizedBox(width: 7),
                      if (me)
                        Badge2('SAYA',
                            fg: K.orangeDeep,
                            bg: context.isDark ? const Color(0x29FF6A13) : K.orangeSoft,
                            radius: 5)
                      else if (m.state != MemberState.offline)
                        Badge2(m.sport.label.toUpperCase(),
                            fg: context.fg, bg: context.fill, radius: 5),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Mono(detail, size: 10.5),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Mono(m.stateLabel,
                    size: 9.5, color: m.stateColor, weight: FontWeight.w700, track: .9),
                Mono(fmtAgo(m.lastPing), size: 9.5),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
