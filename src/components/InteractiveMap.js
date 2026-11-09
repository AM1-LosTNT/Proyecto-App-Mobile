import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  Dimensions,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { WebView } from 'react-native-webview';
import { colors, spacing, borderRadius, shadows } from '../styles/theme';
import { Ionicons } from '@expo/vector-icons';
import { useApp } from '../context/AppContext';

const { width } = Dimensions.get('window');

export const InteractiveMap = ({ selectedFilter = 'all' }) => {
  const {
    mapPoints,
    navigateToDetail,
    user,
    setSelectedMapCoords,
    setCurrentScreen,
  } = useApp();

  // Filtrar puntos por categoría (Hotel, Restaurante, Hospital, Atracciones)
  const filteredPoints = mapPoints.filter((point) => {
    if (selectedFilter === 'all') return true;
    return point.type === selectedFilter;
  });

  const [selectedPoint, setSelectedPoint] = useState(filteredPoints[0] || mapPoints[0]);
  const [clickedCoords, setClickedCoords] = useState(null);
  const [viewMode, setViewMode] = useState('map'); // 'map' | 'list'
  const [mapLoaded, setMapLoaded] = useState(false);
  const webViewRef = useRef(null);

  // Mantener el punto seleccionado sincronizado cuando cambie el filtro
  useEffect(() => {
    if (filteredPoints.length > 0 && !filteredPoints.find((p) => p.id === selectedPoint?.id)) {
      setSelectedPoint(filteredPoints[0]);
    }
  }, [selectedFilter, mapPoints]);

  // Enviar puntos actualizados al WebView cuando cambian los puntos o el filtro
  useEffect(() => {
    if (mapLoaded && webViewRef.current) {
      const payload = JSON.stringify({
        type: 'UPDATE_MARKERS',
        points: filteredPoints,
      });
      webViewRef.current.postMessage(payload);
    }
  }, [filteredPoints, mapLoaded]);

  // Generar el HTML para Leaflet + OpenStreetMap
  const leafletHTML = `
    <!DOCTYPE html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body, #map { width: 100%; height: 100%; background: #F1F5F9; font-family: -apple-system, sans-serif; }
          
          /* Estilo moderno para los marcadores */
          .custom-pin {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 36px;
            height: 36px;
            border-radius: 50%;
            color: #ffffff;
            font-size: 16px;
            box-shadow: 0 4px 10px rgba(0,0,0,0.35);
            border: 2.5px solid #ffffff;
            transition: transform 0.2s ease;
          }
          .pin-hotel { background: #2563EB; }
          .pin-restaurant { background: #EA580C; }
          .pin-hospital { background: #DC2626; }
          .pin-attraction { background: #059669; }
          
          .leaflet-popup-content-wrapper {
            border-radius: 12px;
            padding: 4px;
            font-size: 13px;
            font-weight: 600;
            color: #0F172A;
          }
        </style>
      </head>
      <body>
        <div id="map"></div>
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <script>
          const initialPoints = ${JSON.stringify(filteredPoints)};
          
          // Centro inicial promedio
          const map = L.map('map', { zoomControl: false }).setView([-33.4372, -70.6450], 14);

          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '© OpenStreetMap'
          }).addTo(map);

          let markersLayer = L.layerGroup().addTo(map);

          function getPinEmoji(type) {
            switch(type) {
              case 'hotel': return '🏨';
              case 'restaurant': return '🍽️';
              case 'hospital': return '🏥';
              default: return '⭐';
            }
          }

          function renderMarkers(points) {
            markersLayer.clearLayers();
            points.forEach(p => {
              if (!p.lat || !p.lng) return;
              
              const iconClass = 'pin-' + (p.type || 'attraction');
              const emoji = getPinEmoji(p.type);

              const icon = L.divIcon({
                className: 'custom-div-icon',
                html: '<div class="custom-pin ' + iconClass + '">' + emoji + '</div>',
                iconSize: [36, 36],
                iconAnchor: [18, 18],
                popupAnchor: [0, -18]
              });

              const marker = L.marker([p.lat, p.lng], { icon: icon });
              marker.bindPopup('<b>' + p.name + '</b><br>' + (p.price || ''));
              marker.on('click', () => {
                window.ReactNativeWebView.postMessage(JSON.stringify({
                  type: 'SELECT_POINT',
                  pointId: p.id
                }));
              });
              markersLayer.addLayer(marker);
            });
          }

          renderMarkers(initialPoints);

          // Al hacer clic en el mapa para marcar punto nuevo (para negocio o admin)
          map.on('click', function(e) {
            window.ReactNativeWebView.postMessage(JSON.stringify({
              type: 'MAP_CLICK',
              lat: e.latlng.lat,
              lng: e.latlng.lng
            }));
          });

          // Escuchar mensajes desde React Native
          document.addEventListener('message', handleRNMessage);
          window.addEventListener('message', handleRNMessage);

          function handleRNMessage(event) {
            try {
              const data = JSON.parse(event.data);
              if (data.type === 'UPDATE_MARKERS') {
                renderMarkers(data.points);
              } else if (data.type === 'CENTER_ON') {
                map.flyTo([data.lat, data.lng], 16, { duration: 1.2 });
              } else if (data.type === 'LOCATE') {
                map.locate({ setView: true, maxZoom: 16 });
              }
            } catch(e) {}
          }
        </script>
      </body>
    </html>
  `;

  const handleMessage = (event) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      if (data.type === 'SELECT_POINT') {
        const found = mapPoints.find((p) => p.id === data.pointId);
        if (found) {
          setSelectedPoint(found);
        }
      } else if (data.type === 'MAP_CLICK') {
        setClickedCoords({ lat: data.lat.toFixed(4), lng: data.lng.toFixed(4) });
      }
    } catch (e) {
      console.warn('Error recibiendo mensaje de mapa:', e);
    }
  };

  const centerOnPoint = (point) => {
    setSelectedPoint(point);
    if (webViewRef.current && point.lat && point.lng) {
      webViewRef.current.postMessage(
        JSON.stringify({
          type: 'CENTER_ON',
          lat: point.lat,
          lng: point.lng,
        })
      );
    }
  };

  const locateUser = () => {
    if (webViewRef.current) {
      webViewRef.current.postMessage(JSON.stringify({ type: 'LOCATE' }));
    }
  };

  const handleOpenBusinessRegister = () => {
    if (clickedCoords) {
      setSelectedMapCoords(clickedCoords);
      setCurrentScreen('BusinessPanel');
    }
  };

  return (
    <View style={styles.container}>
      {/* Barra de Controles Superiores: Modo Vista (Mapa vs Lista) y GPS */}
      <View style={styles.controlsBar}>
        <View style={styles.modeTabs}>
          <TouchableOpacity
            style={[styles.modeTab, viewMode === 'map' && styles.modeTabActive]}
            onPress={() => setViewMode('map')}
          >
            <Ionicons
              name="map"
              size={15}
              color={viewMode === 'map' ? colors.primary : colors.textMuted}
            />
            <Text
              style={[
                styles.modeTabText,
                viewMode === 'map' && styles.modeTabTextActive,
              ]}
            >
              Mapa Vivo
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.modeTab, viewMode === 'list' && styles.modeTabActive]}
            onPress={() => setViewMode('list')}
          >
            <Ionicons
              name="list"
              size={15}
              color={viewMode === 'list' ? colors.primary : colors.textMuted}
            />
            <Text
              style={[
                styles.modeTabText,
                viewMode === 'list' && styles.modeTabTextActive,
              ]}
            >
              Lista ({filteredPoints.length})
            </Text>
          </TouchableOpacity>
        </View>

        {viewMode === 'map' && (
          <TouchableOpacity style={styles.gpsButton} onPress={locateUser} activeOpacity={0.8}>
            <Ionicons name="locate" size={18} color={colors.primary} />
            <Text style={styles.gpsText}>GPS</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Vista de Mapa en Vivo con Leaflet */}
      {viewMode === 'map' ? (
        <View style={styles.mapWrapper}>
          <WebView
            ref={webViewRef}
            originWhitelist={['*']}
            source={{ html: leafletHTML }}
            style={styles.webView}
            onMessage={handleMessage}
            onLoadEnd={() => setMapLoaded(true)}
            javaScriptEnabled={true}
            domStorageEnabled={true}
            startInLoadingState={true}
            renderLoading={() => (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color={colors.primary} />
                <Text style={styles.loadingText}>Cargando mapa interactivo...</Text>
              </View>
            )}
          />

          {/* Banner Flotante si se tocó el mapa para marcar ubicación */}
          {clickedCoords && (user.role === 'business' || user.role === 'admin') && (
            <View style={styles.pinBanner}>
              <View style={styles.pinBannerInfo}>
                <Ionicons name="pin" size={18} color={colors.accentWarm} />
                <Text style={styles.pinBannerText}>
                  Lat: {clickedCoords.lat}, Lng: {clickedCoords.lng}
                </Text>
              </View>
              <TouchableOpacity
                style={styles.pinBannerButton}
                onPress={handleOpenBusinessRegister}
              >
                <Text style={styles.pinBannerBtnText}>+ Crear Negocio Aquí</Text>
              </TouchableOpacity>
            </View>
          )}

          {/* Tarjeta Flotante Inferior del Punto Seleccionado */}
          {selectedPoint && (
            <View style={styles.bottomSheet}>
              <TouchableOpacity
                style={styles.sheetCard}
                activeOpacity={0.9}
                onPress={() => centerOnPoint(selectedPoint)}
              >
                <Image
                  source={{ uri: selectedPoint.image }}
                  style={styles.sheetImage}
                />
                <View style={styles.sheetDetails}>
                  <View style={styles.sheetTypeBadge}>
                    <Text style={styles.sheetTypeText}>
                      {selectedPoint.typeName || 'Punto Turístico'}
                    </Text>
                  </View>
                  <Text style={styles.sheetTitle} numberOfLines={1}>
                    {selectedPoint.name}
                  </Text>
                  <Text style={styles.sheetAddress} numberOfLines={1}>
                    {selectedPoint.address}
                  </Text>
                  <View style={styles.sheetBottomRow}>
                    <View style={styles.ratingBadge}>
                      <Ionicons name="star" size={13} color="#F59E0B" />
                      <Text style={styles.ratingText}>{selectedPoint.rating}</Text>
                    </View>
                    <Text style={styles.sheetPrice}>{selectedPoint.price}</Text>
                  </View>
                </View>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.viewDetailBtn}
                onPress={() => {
                  navigateToDetail({
                    id: selectedPoint.id,
                    name: selectedPoint.name,
                    category: selectedPoint.type || 'lugares',
                    categoryName: selectedPoint.typeName || 'Turismo',
                    rating: selectedPoint.rating,
                    reviewsCount: 45,
                    price: 35,
                    location: selectedPoint.address,
                    images: [selectedPoint.image],
                    description: selectedPoint.description,
                  });
                }}
              >
                <Text style={styles.viewDetailBtnText}>Ver Detalles Completos</Text>
                <Ionicons name="arrow-forward" size={15} color="#FFFFFF" />
              </TouchableOpacity>
            </View>
          )}
        </View>
      ) : (
        /* Vista en Lista alternativa con scroll y acceso directo */
        <View style={styles.listContainer}>
          {filteredPoints.map((item) => (
            <TouchableOpacity
              key={item.id}
              style={styles.listItem}
              onPress={() => {
                centerOnPoint(item);
                setViewMode('map');
              }}
              activeOpacity={0.8}
            >
              <Image source={{ uri: item.image }} style={styles.listThumb} />
              <View style={styles.listContent}>
                <Text style={styles.listTag}>{item.typeName}</Text>
                <Text style={styles.listTitle} numberOfLines={1}>
                  {item.name}
                </Text>
                <Text style={styles.listAddress} numberOfLines={1}>
                  {item.address}
                </Text>
                <View style={styles.listFooter}>
                  <Text style={styles.listPrice}>{item.price}</Text>
                  <View style={styles.ratingBadge}>
                    <Ionicons name="star" size={12} color="#F59E0B" />
                    <Text style={styles.ratingText}>{item.rating}</Text>
                  </View>
                </View>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
            </TouchableOpacity>
          ))}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  controlsBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  modeTabs: {
    flexDirection: 'row',
    backgroundColor: colors.surfaceSecondary,
    borderRadius: borderRadius.md,
    padding: 3,
  },
  modeTab: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: 5,
    paddingHorizontal: 12,
    borderRadius: borderRadius.sm,
  },
  modeTabActive: {
    backgroundColor: colors.surface,
    ...shadows.sm,
  },
  modeTabText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textMuted,
  },
  modeTabTextActive: {
    color: colors.primary,
  },
  gpsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: colors.surfaceSecondary,
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: borderRadius.md,
  },
  gpsText: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primary,
  },
  mapWrapper: {
    flex: 1,
    position: 'relative',
  },
  webView: {
    flex: 1,
    backgroundColor: '#F1F5F9',
  },
  loadingContainer: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#FFFFFF',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
  },
  loadingText: {
    marginTop: 10,
    fontSize: 13,
    color: colors.textSecondary,
    fontWeight: '600',
  },
  pinBanner: {
    position: 'absolute',
    top: 10,
    left: spacing.md,
    right: spacing.md,
    backgroundColor: colors.surface,
    borderRadius: borderRadius.md,
    padding: spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    ...shadows.md,
    borderLeftWidth: 4,
    borderLeftColor: colors.primary,
    zIndex: 20,
  },
  pinBannerInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  pinBannerText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textPrimary,
  },
  pinBannerButton: {
    backgroundColor: colors.primary,
    paddingVertical: 5,
    paddingHorizontal: 10,
    borderRadius: borderRadius.sm,
  },
  pinBannerBtnText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '700',
  },
  bottomSheet: {
    position: 'absolute',
    bottom: 12,
    left: spacing.md,
    right: spacing.md,
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    padding: spacing.sm,
    ...shadows.lg,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  sheetCard: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  sheetImage: {
    width: 72,
    height: 72,
    borderRadius: borderRadius.md,
  },
  sheetDetails: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  sheetTypeBadge: {
    alignSelf: 'flex-start',
    backgroundColor: colors.surfaceSecondary,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: borderRadius.xs,
    marginBottom: 2,
  },
  sheetTypeText: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.primary,
    textTransform: 'uppercase',
  },
  sheetTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  sheetAddress: {
    fontSize: 11,
    color: colors.textSecondary,
    marginVertical: 2,
  },
  sheetBottomRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 2,
  },
  ratingBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
  },
  ratingText: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  sheetPrice: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primary,
  },
  viewDetailBtn: {
    marginTop: spacing.xs,
    backgroundColor: colors.primary,
    paddingVertical: 8,
    borderRadius: borderRadius.md,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  viewDetailBtnText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '700',
  },
  listContainer: {
    flex: 1,
    padding: spacing.md,
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderRadius: borderRadius.md,
    padding: spacing.sm,
    marginBottom: spacing.sm,
    ...shadows.sm,
    borderWidth: 1,
    borderColor: colors.borderLight,
  },
  listThumb: {
    width: 65,
    height: 65,
    borderRadius: borderRadius.sm,
  },
  listContent: {
    flex: 1,
    marginLeft: spacing.sm,
  },
  listTag: {
    fontSize: 10,
    fontWeight: '700',
    color: colors.primary,
    textTransform: 'uppercase',
  },
  listTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  listAddress: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 1,
  },
  listFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 4,
  },
  listPrice: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primary,
  },
});
