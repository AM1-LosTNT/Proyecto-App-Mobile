import 'package:flutter/material.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherForecastResult? _forecast;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await WeatherService.fetchForecast(forceRefresh: forceRefresh);
      if (!mounted) return;
      if (res != null) {
        setState(() {
          _forecast = res;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No se pudo cargar el pronóstico del clima. Intenta de nuevo.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexión con el servicio del clima.';
        _isLoading = false;
      });
    }
  }

  String _formatDayName(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Hoy';
      }
      final tomorrow = now.add(const Duration(days: 1));
      if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
        return 'Mañana';
      }

      const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return '${days[date.weekday - 1]} ${date.day}/${date.month}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.wb_sunny_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Clima & Pronóstico'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadWeather(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 14),
            Text(
              'Consultando pronóstico del clima...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadWeather(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final forecast = _forecast!;
    final current = forecast.current;

    return RefreshIndicator(
      onRefresh: () => _loadWeather(forceRefresh: true),
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Tarjeta Principal: Clima Actual
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Santa Cruz de la Sierra',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'En vivo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${current.temperature.toStringAsFixed(1)}°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          current.weatherDescription,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      current.weatherIcon,
                      size: 68,
                      color: Colors.amberAccent.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _WeatherStatItem(
                      icon: Icons.water_drop_outlined,
                      label: 'Humedad',
                      value: '${current.humidity}%',
                    ),
                    _WeatherStatItem(
                      icon: Icons.air_rounded,
                      label: 'Viento',
                      value: '${current.windSpeed.toStringAsFixed(0)} km/h',
                    ),
                    _WeatherStatItem(
                      icon: Icons.grain_rounded,
                      label: 'Lluvia',
                      value: '${current.precipitation.toStringAsFixed(1)} mm',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Título de Pronóstico de 10 Días
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Pronóstico de 10 días',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de los 10 días
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: forecast.daily.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final day = forecast.daily[index];
              final isToday = index == 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppTheme.primaryColor.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isToday
                        ? AppTheme.primaryColor.withValues(alpha: 0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    // Día
                    SizedBox(
                      width: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDayName(day.date),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isToday ? AppTheme.primaryColor : AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            day.weatherDescription,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Icono de Clima
                    Icon(day.weatherIcon, color: Colors.blueAccent, size: 26),
                    const SizedBox(width: 14),

                    // Probabilidad de Lluvia
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.water_drop_rounded, size: 14, color: Colors.lightBlue),
                          const SizedBox(width: 3),
                          Text(
                            '${day.precipitationProbability}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: day.precipitationProbability > 50
                                  ? Colors.blue.shade700
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.air_rounded, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 3),
                          Text(
                            '${day.windSpeedMax.toStringAsFixed(0)}k/h',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),

                    // Rango de Temperaturas (Mín / Máx)
                    Row(
                      children: [
                        Text(
                          '${day.tempMin.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Text(
                          ' / ',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          '${day.tempMax.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeatherStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
