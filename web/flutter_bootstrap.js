{{flutter_js}}
{{flutter_build_config}}

// Self-host CanvasKit. Domestic production deployments must not depend on
// Google CDN availability; otherwise the app can remain on the splash screen.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
