import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/disease_info.dart';
import '../common/nav.dart';
import '../common/widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('disease_library'))),
      body: FutureBuilder<Map<String, DiseaseInfo>>(
        future: DiseaseInfoRepository.instance.load(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(s.t('err_generic')));
          final data = snap.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: DiseaseInfoRepository.order.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final key = DiseaseInfoRepository.order[i];
              final info = data[key];
              if (info == null) return const SizedBox.shrink();
              final style = ResultStyle.of(key, dark: dark);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => push(context, DiseaseDetailScreen(info: info)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: style.color.withValues(alpha: 0.15),
                        child: Icon(style.icon, color: style.color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.label(key), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(info.summary, style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                      ),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DiseaseDetailScreen extends StatelessWidget {
  const DiseaseDetailScreen({super.key, required this.info});
  final DiseaseInfo info;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.label(info.key))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ResultBadge(label: info.key, large: true),
        const SizedBox(height: 12),
        Text(info.summary, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        DiseaseInfoSections(info: info, expandDoctor: true),
        const SizedBox(height: 16),
        const DisclaimerBar(),
      ]),
    );
  }
}
