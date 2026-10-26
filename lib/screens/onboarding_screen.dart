import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../widgets/data_actions.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';

class _IntroPage {
  const _IntroPage(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _IntroPage(
    Icons.wb_twilight,
    'Plan the day before it plans you.',
    'Daybreak turns your task list into a schedule.',
  ),
  _IntroPage(
    Icons.edit_note,
    'Add your tasks',
    'Give each one a due date, how important it is, and how long you think '
        'it\'ll take.',
  ),
  _IntroPage(
    Icons.view_timeline_outlined,
    'Get a real plan',
    'Daybreak fits them around your commitments with 50/10 focus sessions.',
  ),
  _IntroPage(
    Icons.insights,
    'It learns your pace',
    'Log your time. Daybreak learns your pace and plans better tomorrow.',
  ),
];

/// Short intro shown on first launch (and from Settings → Show intro again).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = context.read<SettingsProvider>();
    await settings.updateSettings(
      settings.settings.copyWith(hasOnboarded: true),
    );
  }

  Future<void> _tryDemo() async {
    setState(() => _busy = true);
    await loadDemo(context);
  }

  void _next() {
    // Page animations can't have a zero duration, so jump when motion is off.
    if (Motion.reduced(context)) {
      _controller.jumpToPage(_page + 1);
      return;
    }
    _controller.nextPage(duration: Motion.medium, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.s),
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: Motion.of(context, Motion.fast),
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _IntroPageView(page: _pages[i]),
              ),
            ),
            _pageDots(colors),
            _bottomButtons(),
          ],
        ),
      ),
    );
  }

  /// One dot per page; the current page's dot is wider.
  Widget _pageDots(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.l),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _pages.length; i++)
            AnimatedContainer(
              duration: Motion.of(context, Motion.medium),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _page ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _page ? colors.primary : colors.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  /// "Next" on every page; "Get started" and "Try with demo data" on the last.
  Widget _bottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        child: _isLast
            ? Column(
                key: const ValueKey('last'),
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Get started'),
                  ),
                  const SizedBox(height: Spacing.s),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _tryDemo,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Try with demo data'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              )
            : FilledButton(
                key: const ValueKey('next'),
                onPressed: _next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Next'),
              ),
      ),
    );
  }
}

class _IntroPageView extends StatelessWidget {
  const _IntroPageView({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      child: Column(
        children: [
          const SizedBox(height: Spacing.xl),
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: DaybreakColors.of(context).dawnMorning,
              ),
            ),
            child: Icon(
              page.icon,
              size: 84,
              color: DaybreakColors.of(context).onDawn,
            ),
          ),
          const SizedBox(height: Spacing.xl + Spacing.s),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.m),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
