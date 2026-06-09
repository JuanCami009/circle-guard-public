// karate-config.js — Configuración global para la suite E2E CircleGuard
// Lee variables de entorno (mismas que usan los Jenkinsfiles) con defaults para dev local.
function fn() {
  var host = java.lang.System.getenv('E2E_HOST') || 'host.docker.internal';

  // NodePorts por entorno:
  //   dev   → 31082..31180  (Jenkinsfile.dev)
  //   stage → 32082..32180  (Jenkinsfile.stage)
  //   prod  → 30082..30180  (Jenkinsfile.master)
  //   local → localhost mismos puertos
  var portAuth         = java.lang.System.getenv('E2E_PORT_AUTH')         || '31180';
  var portNotification = java.lang.System.getenv('E2E_PORT_NOTIFICATION') || '31082';
  var portIdentity     = java.lang.System.getenv('E2E_PORT_IDENTITY')     || '31083';
  var portDashboard    = java.lang.System.getenv('E2E_PORT_DASHBOARD')    || '31084';
  var portFile         = java.lang.System.getenv('E2E_PORT_FILE')         || '31085';
  var portForm         = java.lang.System.getenv('E2E_PORT_FORM')         || '31086';
  var portGateway      = java.lang.System.getenv('E2E_PORT_GATEWAY')      || '31087';
  var portPromotion    = java.lang.System.getenv('E2E_PORT_PROMOTION')    || '31088';

  var config = {
    baseUrlAuth:         'http://' + host + ':' + portAuth,
    baseUrlNotification: 'http://' + host + ':' + portNotification,
    baseUrlIdentity:     'http://' + host + ':' + portIdentity,
    baseUrlDashboard:    'http://' + host + ':' + portDashboard,
    baseUrlFile:         'http://' + host + ':' + portFile,
    baseUrlForm:         'http://' + host + ':' + portForm,
    baseUrlGateway:      'http://' + host + ':' + portGateway,
    baseUrlPromotion:    'http://' + host + ':' + portPromotion,

    // Credenciales de usuario de prueba (Jenkins: e2e-username / e2e-password)
    // Si no están, los journeys de login usan el JWT inyectado (TEST_JWT / TEST_ANON_ID)
    e2eUsername: java.lang.System.getenv('E2E_USERNAME') || '',
    e2ePassword: java.lang.System.getenv('E2E_PASSWORD') || '',

    // Fallback: JWT + anonId pre-autenticados (mismas credenciales de Jenkins actuales)
    fallbackJwt:    java.lang.System.getenv('TEST_JWT')     || '',
    fallbackAnonId: java.lang.System.getenv('TEST_ANON_ID') || '',

    // QR token pre-generado (opcional; si no hay, el journey lo genera via qr/generate)
    prebuiltQrToken: java.lang.System.getenv('TEST_QR_TOKEN') || '',
  };

  // Helper reutilizable: intenta login live, cae a JWT inyectado si no hay creds
  // Retorna { jwt: '...', anonId: '...' } o null si ninguno disponible
  config.doLogin = function(username, password) {
    if (!username || !password) return null;
    var result = karate.call('classpath:e2e/helpers/login.feature', { username: username, password: password, baseUrlAuth: config.baseUrlAuth });
    return result;
  };

  // Helper: obtener contexto autenticado (live login > fallback JWT inyectado)
  config.getAuthContext = function() {
    if (config.e2eUsername && config.e2ePassword) {
      var r = config.doLogin(config.e2eUsername, config.e2ePassword);
      if (r && r.jwt) return r;
    }
    if (config.fallbackJwt && config.fallbackAnonId) {
      return { jwt: config.fallbackJwt, anonId: config.fallbackAnonId };
    }
    return null;
  };

  return config;
}
