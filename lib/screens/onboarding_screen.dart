import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../shell/scope.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = TripScope.of(context);
    return Material(
      color: AppColors.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('TripWeave', key: const Key('onboarding-brand'), style: AppType.largeTitle, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.lg),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (index) => setState(() => _step = index),
                  children: [
                    _WelcomePage(step: 0, current: _step),
                    _ChoicePage(
                      onCreate: controller.startOnboardingCreate,
                      onBrowse: () {
                        controller.browseBundledSamples();
                      },
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  2,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: index == _step ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: index == _step ? AppColors.accent : AppColors.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              if (_step == 0)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: AppButton(key: const Key('onboarding-next'), label: '다음', onPressed: () => _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut)),
                  ),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.step, required this.current});

  final int step;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('onboarding-welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(CupertinoIcons.airplane, size: 40, color: AppColors.accent.withValues(alpha: step == current ? 1 : 0.5)),
        const SizedBox(height: AppSpace.md),
        Text('도시·기간만 정하면 일정을 제안합니다', style: AppType.title),
        const SizedBox(height: AppSpace.sm),
        Text(
          '탐색에서 장소를 고르고, 일정을 다듬은 뒤 여행 중에는 다음 목적지와 길찾기까지 한곳에서 이어갑니다.',
          style: AppType.body.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: AppSpace.lg),
        Text('시작 방법', style: AppType.section),
        const SizedBox(height: AppSpace.xs),
        Text('다음 화면에서 내 여행을 만들거나, 샘플 여행을 먼저 둘러볼 수 있습니다.', style: AppType.footnote),
      ],
    );
  }
}

class _ChoicePage extends StatelessWidget {
  const _ChoicePage({required this.onCreate, required this.onBrowse});

  final VoidCallback onCreate;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('onboarding-choice'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('어디로, 언제 가시나요?', style: AppType.title),
        const SizedBox(height: AppSpace.sm),
        Text('여행을 만들면 홈 목록에 저장됩니다. 샘플은 데모용이며 내 여행과 섞이지 않게 따로 보여 줍니다.', style: AppType.body.copyWith(color: AppColors.secondary)),
        const Spacer(),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                AppButton(key: const Key('onboarding-create'), label: '여행 만들기', onPressed: onCreate),
                const SizedBox(height: AppSpace.sm),
                AppButton(key: const Key('onboarding-browse-samples'), label: '샘플 둘러보기', filled: false, onPressed: onBrowse),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
