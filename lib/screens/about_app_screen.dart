import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран "О приложении" с информацией и картинками
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
      image: 'assets/splash_icon.webp',
      title: 'Прогулкин',
      subtitle: 'Трекер прогулок',
      text: 'Добро пожаловать в Прогулкин! Это приложение поможет вам отслеживать ваши прогулки, '
          'исследовать окрестности и делать прогулки более интересными и полезными. '
          'Записывайте маршруты, считайте шаги и открывайте новые места!',
    ),
    _PageContent(
      image: 'assets/splash_icon.webp',
      title: '🚶 Запись прогулок',
      subtitle: 'Отслеживайте свой путь',
      text: 'Нажмите "Начать прогулку" и приложение начнёт записывать ваш маршрут. '
          'Вы увидите пройденное расстояние, время, скорость и количество шагов. '
          'GPS-трек сохраняется и его можно просмотреть в истории прогулок.',
    ),
    _PageContent(
      image: 'assets/splash_icon.webp',
      title: '👹 Мусорные монстры',
      subtitle: 'Убирайте территорию',
      text: 'На карте появляются мусорные монстры — отметьте место где нужно убрать мусор. '
          'Другие пользователи могут подтвердить или убрать монстра, получая очки репутации. '
          'Вместе мы делаем мир чище!',
    ),
    _PageContent(
      image: 'assets/splash_icon.webp',
      title: '🦊 Лесные существа',
      subtitle: 'Собирайте коллекцию',
      text: 'Во время прогулок на карте появляются лесные существа — лисички, зайчики, ёжики и другие! '
          'Поймайте их, чтобы пополнить свою коллекцию. Редкие существа встречаются реже '
          'и приносят больше очков.',
    ),
    _PageContent(
      image: 'assets/splash_icon.webp',
      title: '🍄 Грибы и ягоды',
      subtitle: 'Отмечайте находки',
      text: 'Нашли грибное место или поляну с ягодами? Отметьте на карте! '
          'Выберите тип находки: грибы, ягоды, орехи или травы. '
          'Добавьте фото и помогите другим прогульщикам найти вкусные места!',
    ),
    _PageContent(
      image: 'assets/splash_icon.webp',
      title: '💬 Сообщения',
      subtitle: 'Общайтесь с другими',
      text: 'Оставляйте секретные сообщения в любых местах для других прогульщиков. '
          'Также можете отметить места, которые вас заинтересовали. '
          'P2P-синхронизация позволяет обмениваться данными напрямую между устройствами.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              return _buildPage(_pages[index]);
            },
          ),

          // Индикатор страниц
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: _buildPageIndicator(),
          ),

          // Кнопки навигации
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: _buildNavigationButtons(),
          ),

          // Кнопка пропустить (только на первых страницах)
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: 50,
              right: 16,
              child: TextButton(
                onPressed: () => _finish(),
                child: const Text('Пропустить'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(_PageContent page) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Картинка
              Expanded(
                flex: 2,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Image.asset(
                    page.image,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_walk,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Заголовок
              Text(
                page.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Подзаголовок
              Text(
                page.subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Текст
              Text(
                page.text,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
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
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            child: OutlinedButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
