import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран "О приложении" с полноэкранными картинками и текстом
class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_PageContent> _pages = [
    _PageContent(
      image: 'assets/splash_intro.webp',
      title: 'Прогулкин',
      subtitle: 'Трекер прогулок',
      text: 'Добро пожаловать! Это приложение поможет вам отслеживать ваши прогулки, '
          'исследовать окрестности и делать прогулки более интересными и полезными. '
          'Записывайте маршруты, считайте шаги и открывайте новые места!',
    ),
    _PageContent(
      image: 'assets/splash_record.webp',
      title: 'Запись',
      subtitle: 'Отслеживайте свой путь',
      text: 'Нажмите "Начать прогулку" и приложение начнёт записывать ваш маршрут. '
          'Вы увидите пройденное расстояние, время, скорость и количество шагов. '
          'GPS-трек сохраняется и его можно просмотреть в истории прогулок.',
    ),
    _PageContent(
      image: 'assets/splash_monstr.webp',
      title: '👹 Монстры',
      subtitle: 'Убирайте территорию',
      text: 'Отмечайте места, где нужно убрать мусор. На карте появляются мусорные монстры. '
          'Другие пользователи или вы сами можете убирать монстров, получая очки репутации. '
          'Вместе мы делаем мир чище!',
    ),
    _PageContent(
      image: 'assets/splash_creature.webp',
      title: '🦊 Существа',
      subtitle: 'Собирайте коллекцию',
      text: 'Во время прогулок на карте появляются мифические существа — Лешии, Баба-яга, Домовой и другие! '
          'Приручите их, чтобы пополнить коллекцию. Делитесь с ними угощением.',
    ),
    _PageContent(
      image: 'assets/splash_berries.webp',
      title: '🍄 Находки',
      subtitle: 'Отмечайте находки',
      text: 'Нашли грибное место или поляну с ягодами? Отметьте на карте! '
          'Выберите тип находки: грибы, ягоды, орехи или травы. '
          'Добавьте фото и помогите другим путешественникам найти хорошие места!',
    ),
    _PageContent(
      image: 'assets/splash_msgs.webp',
      title: '💬 Сообщения',
      subtitle: 'Общайтесь с соседями',
      text: 'Оставляйте секретные сообщения в любых местах. '
          'Также можете отметить места, которые вас заинтересовали. И написать другим путешественникам, чьи заметки вам понравились. '
          'P2P-синхронизация позволяет обмениваться данными напрямую между устройствами. Но можно передать объекты и файлом друзьям.',
    ),
    _PageContent(
      image: 'assets/splash_icon.webp',
      title: 'Здоровье',
      subtitle: 'Движение - жизнь',
      text: 'Прогулки помогают поддерживать здоровье и улучшают настроение. Ходите больше и поделитесь впечатлениями с друзьями.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Получаем нижний отступ для системной навигации
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      body: Stack(
        children: [
          // Страницы с контентом
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPage(_pages[index], bottomPadding);
            },
          ),

          // Затемнение сверху для статус-бара
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Индикатор страниц (выше кнопок с учётом SafeArea)
          Positioned(
            bottom: 80 + bottomPadding,
            left: 0,
            right: 0,
            child: _buildPageIndicator(),
          ),

          // Кнопки навигации
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: _buildNavigationButtons(),
              ),
            ),
          ),

          // Кнопка пропустить (только на первых страницах)
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: 50,
              right: 16,
              child: TextButton(
                onPressed: () => _finish(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Пропустить'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(_PageContent page, double bottomPadding) {
    // Место для индикатора (30) + кнопок (~60) + SafeArea
    final bottomSpace = 100 + bottomPadding;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Полноэкранная картинка на фоне
        Image.asset(
          page.image,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.indigo[900]!,
                    Colors.purple[800]!,
                    Colors.deepPurple[700]!,
                  ],
                ),
              ),
            );
          },
        ),

        // Контент
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Заголовок
                      Text(
                        page.title,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      // Подзаголовок
                      Text(
                        page.subtitle,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.8),
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Текст
                      Text(
                        page.text,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: bottomSpace), // Место для индикатора и кнопок
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildNavigationButtons() {
    final isLastPage = _currentPage == _pages.length - 1;

    if (isLastPage) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _finish(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 8,
          ),
          child: const Text(
            'Начать прогулки!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Row(
      children: [
        if (_currentPage > 0)
          Expanded(
            child: TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Назад'),
            ),
          ),
        if (_currentPage > 0) const SizedBox(width: 16),
        Expanded(
          flex: _currentPage > 0 ? 1 : 2,
          child: ElevatedButton(
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
            ),
            child: const Text('Далее'),
          ),
        ),
      ],
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_shown', true);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _PageContent {
  final String image;
  final String title;
  final String subtitle;
  final String text;

  const _PageContent({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.text,
  });
}

/// Проверяет, нужно ли показать вводный экран
Future<bool> shouldShowIntro() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool('intro_shown') ?? false);
}
