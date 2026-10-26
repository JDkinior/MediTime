/**
 * MEDITIME - Dynamic Web Functionality & Modern Interactions (v2.32.0)
 */

// Transiciones entre documentos: los navegadores compatibles usan la API nativa
// declarada en CSS. En los demás, se aplica una salida ligera antes de navegar.
const reducedPageMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

document.addEventListener('DOMContentLoaded', () => {
  // --- SELECTORS & HELPERS ---
  const $ = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => Array.from(ctx.querySelectorAll(sel));

  // Helper to scroll to section with optimal centering below the fixed navbar
  function scrollToTargetSection(targetElem, smooth = false) {
    if (!targetElem) return;
    // When targeting hero, home, or body, always scroll to the absolute top of the page (scrollY = 0)
    if (targetElem.id === 'hero' || targetElem.id === 'home' || targetElem.tagName === 'BODY' || targetElem.tagName === 'HTML') {
      window.scrollTo({
        top: 0,
        left: 0,
        behavior: smooth ? 'smooth' : 'auto'
      });
      return;
    }

    const headerElem = $('.header');
    const headerHeight = headerElem ? headerElem.getBoundingClientRect().height : (window.innerWidth < 768 ? 64 : 68);
    const extraGap = window.innerWidth < 768 ? 12 : 18;
    const headerOffset = headerHeight + extraGap;

    // Target the inner container (.container or .container-wide) to bypass large section padding-top
    const scrollTarget = targetElem.querySelector(':scope > .container') ||
                         targetElem.querySelector(':scope > .container-wide') ||
                         targetElem;

    const top = scrollTarget.getBoundingClientRect().top + window.scrollY - headerOffset;
    window.scrollTo({
      top: Math.max(0, top),
      behavior: smooth ? 'smooth' : 'auto'
    });
  }

  // Re-align cross-page anchors after the destination layout and fonts settle.
  function alignHashTarget(smooth = false) {
    const hash = window.location.hash;
    if (!hash) return;

    const target = document.getElementById(decodeURIComponent(hash.slice(1)));
    if (!target) return;

    scrollToTargetSection(target, smooth);

    requestAnimationFrame(() => {
      scrollToTargetSection(target, smooth);
      setTimeout(() => {
        scrollToTargetSection(target, smooth);
      }, 60);
      setTimeout(() => {
        scrollToTargetSection(target, smooth);
      }, 200);
    });
  }

  alignHashTarget(false);
  window.addEventListener('load', () => alignHashTarget(false), { once: true });
  window.addEventListener('pageshow', () => alignHashTarget(false));
  window.addEventListener('hashchange', () => alignHashTarget(true));

  
  // Always scroll to absolute top when clicking brand logo on the home page
  $$('.brand-wrapper').forEach(brand => {
    brand.addEventListener('click', (e) => {
      const currentPath = window.location.pathname.replace(/\/$/, '');
      const isIndex = currentPath.endsWith('index.html') || currentPath === '' || currentPath.endsWith('MediTime%20Page') || currentPath.endsWith('MediTime Page') || !currentPath.includes('.html');
      if (isIndex) {
        e.preventDefault();
        window.scrollTo({
          top: 0,
          left: 0,
          behavior: 'smooth'
        });
        if (history.pushState) {
          history.pushState(null, '', window.location.pathname);
        }
      }
    });
  });

  // --- 0. PAGE TRANSITIONS ---
  function isNavigableInternalPage(link, event) {
    if (reducedPageMotion || event.defaultPrevented) return false;
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false;
    if (link.target && link.target !== '_self') return false;
    if (link.hasAttribute('download')) return false;

    const destination = new URL(link.href, window.location.href);
    const current = window.location;
    const isSameDocument = destination.pathname === current.pathname &&
      destination.search === current.search;

    return destination.origin === current.origin && !isSameDocument;
  }

  document.addEventListener('click', (event) => {
    const link = event.target.closest('a[href]');
    if (!link || !isNavigableInternalPage(link, event)) return;

    event.preventDefault();
    window.location.assign(link.href);
  });

    window.addEventListener('pageshow', () => {
      document.body.classList.remove('page-leaving');
      document.documentElement.classList.remove('page-entering');
      document.body.classList.add('page-ready');
    });

  // --- 0b. ENLACE A LA PÁGINA ACTUAL: SCROLL AL HERO EN VEZ DE RECARGAR ---
  document.addEventListener('click', (event) => {
    const link = event.target.closest('a[href]');
    if (!link || link.hasAttribute('download')) return;
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (link.target && link.target !== '_self') return;

    const destination = new URL(link.href, window.location.href);
    const current = window.location;
    const isSamePage = destination.origin === current.origin &&
      destination.pathname === current.pathname &&
      destination.search === current.search;

    if (!isSamePage || destination.hash) return;

    event.preventDefault();
    window.scrollTo({ top: 0, behavior: reducedPageMotion ? 'auto' : 'smooth' });
  });

  // --- 1. THEME MANAGER (DARK / LIGHT) ---
  const themeToggleBtn = $('#theme-toggle');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');

  const MOON_ICON = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>';
  const SUN_ICON = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>';

  function initTheme() {
    const savedTheme = localStorage.getItem('meditime_theme');
    const targetTheme = savedTheme || (prefersDark.matches ? 'dark' : 'light');
    setTheme(targetTheme, false);
  }

  function setTheme(theme, save = true) {
    document.documentElement.setAttribute('data-theme', theme);
    document.dispatchEvent(new CustomEvent('meditime-theme-change', { detail: { theme } }));
    if (themeToggleBtn) {
      themeToggleBtn.innerHTML = theme === 'dark' ? SUN_ICON : MOON_ICON;
      themeToggleBtn.setAttribute('aria-label', theme === 'dark' ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro');
    }
    const metaThemes = document.querySelectorAll('meta[name="theme-color"]');
    metaThemes.forEach(m => {
      m.setAttribute('content', theme === 'dark' ? '#090d16' : '#ffffff');
    });
    if (save) {
      localStorage.setItem('meditime_theme', theme);
    }
  }

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') || 'light';
      setTheme(current === 'dark' ? 'light' : 'dark', true);
    });
  }

  prefersDark.addEventListener('change', (e) => {
    if (!localStorage.getItem('meditime_theme')) {
      setTheme(e.matches ? 'dark' : 'light', false);
    }
  });

  initTheme();

  // --- 2. MOBILE NAVIGATION MENU ---
  const menuToggle = $('#menu-toggle');
  const mobileNav = $('#mobile-nav');

  if (menuToggle && mobileNav) {
    menuToggle.addEventListener('click', () => {
      const isOpen = mobileNav.classList.toggle('active');
      menuToggle.classList.toggle('active');
      menuToggle.setAttribute('aria-expanded', String(isOpen));
      document.body.style.overflow = isOpen ? 'hidden' : '';
    });

    $$('.nav-link', mobileNav).forEach(link => {
      link.addEventListener('click', () => {
        mobileNav.classList.remove('active');
        menuToggle.classList.remove('active');
        menuToggle.setAttribute('aria-expanded', 'false');
        document.body.style.overflow = '';
      });
    });

    document.addEventListener('click', (e) => {
      if (mobileNav.classList.contains('active') && !mobileNav.contains(e.target) && !menuToggle.contains(e.target)) {
        mobileNav.classList.remove('active');
        menuToggle.classList.remove('active');
        menuToggle.setAttribute('aria-expanded', 'false');
        document.body.style.overflow = '';
      }
    });

    document.addEventListener('keydown', (e) => {
      if (e.key !== 'Escape' || !mobileNav.classList.contains('active')) return;
      mobileNav.classList.remove('active');
      menuToggle.classList.remove('active');
      menuToggle.setAttribute('aria-expanded', 'false');
      document.body.style.overflow = '';
    });
  }

  // --- 2b. HEADER SCROLLED STATE ---
  const pageHeader = $('header.header');
  if (pageHeader) {
    const toggleScrolled = () => pageHeader.classList.toggle('scrolled', window.scrollY > 10);
    toggleScrolled();
    window.addEventListener('scroll', toggleScrolled, { passive: true });
  }

  // --- 3. DYNAMIC GITHUB API CHANGELOG & RELEASES (SPOTLIGHT & HUB) ---
  const GITHUB_OWNER = 'JDkinior';
  const GITHUB_REPO = 'MediTime';
  const RELEASES_CACHE_KEY = 'meditime_github_releases_v2';
  const CACHE_TTL_MS = 1000 * 60 * 60 * 3; // 3 horas

  // Fallback data precompilado con la información exacta del proyecto y v2.32.0
  const FALLBACK_RELEASES = [
    {
      tag_name: 'v2.32.0',
      name: 'MediTime v2.32.0 – Suscripciones Premium, Micro-Consejos con IA y Gestión Multiperfil Robusta',
      published_at: '2026-09-18T05:51:43Z',
      apk_url: 'https://github.com/JDkinior/MediTime/releases/download/v2.32.0/MediTime.apk',
      body: `### Novedades Principales
- **Sistema de Suscripciones y Modelo Freemium Ético:** Nivel Gratuito de acceso universal (hasta 3 tratamientos y 1 perfil dependiente con alarmas de hardware sin restricciones) y planes Premium con tratamientos ilimitados y reportes PDF.
- **Micro-Consejos Farmacológicos con IA:** Sugerencias médicas en tiempo real analizando medicamentos activos y adherencia del día, con caché en disco de 12 horas y heurísticas instantáneas (ayunas para omeprazol, protección gástrica con AINEs, pautas de antibióticos).
- **Gestión Multiperfil Robusta:** Soporte transparente para Modo Cuidador (paleta morada) y Modo Animales/Mascotas (paleta verde) con resolución automática de recetas y avatares fotográficos.

### Mejoras Técnicas & Estabilidad
- **Optimización de Alarmas Nativas:** Silenciamiento limpio y control de recursos evitando hilos huérfanos con \`AlarmSoundPlugin\`.
- **Almacenamiento Local Seguro:** Base de datos SQLite cifrada con funcionamiento 100% offline.`
    },
    {
      tag_name: 'v.2.28.0',
      name: 'MediTime v2.28.0 - Rediseño Serene Health y Reportes de Adherencia Interactivos',
      published_at: '2026-06-24T07:58:35Z',
      apk_url: 'https://github.com/JDkinior/MediTime/releases/download/v.2.28.0/app-debug.apk',
      body: `### Novedades Principales
- **Rediseño Serene Health:** Implementación del nuevo sistema de diseño minimalista médico "Clinical Warmth" con contraste optimizado y capas tonales suaves.
- **Reportes de Adherencia Interactivos:** Visualización gráfica del progreso terapéutico con porcentajes y métricas de cumplimiento para médicos.

### Mejoras Técnicas & Estabilidad
- **Edge-to-Edge Nativo:** Adaptación completa a barras de navegación de Android modernas en tema claro y oscuro.
- **Optimización de Rendimiento:** Reducción del tamaño de la aplicación y arranque un 30% más veloz.`
    },
    {
      tag_name: 'v2.27.0',
      name: 'MediTime 2.27.0 - Chatbot Midi + Mejoras UI',
      published_at: '2026-05-14T04:42:29Z',
      apk_url: 'https://github.com/JDkinior/MediTime/releases/download/v2.27.0/MediTime.2.27.0.apk',
      body: `### Novedades Principales
- **Llegada de Midi:** Chatbot inteligente integrado con Groq API y LLaMA 3.1 con soporte bilingüe en español e inglés y avatar con animación de parpadeo.
- **Streaming de Respuestas:** Visualización progresiva de orientación médica y soporte técnico.

### Correcciones de Errores
- **Ajustes en Vistas:** Corrección en el selector de horas para esquemas con intervalos irregulares.`
    },
    {
      tag_name: 'v2.26.5-android',
      name: 'MediTime 2.26.5 Android - Clean Architecture & Reportes PDF',
      published_at: '2025-08-07T09:26:28Z',
      apk_url: 'https://github.com/JDkinior/MediTime/releases/download/v2.26.5-android/MediTime.2.26.5.apk',
      body: `### Novedades Principales
- **Generación de Reportes PDF:** Exportación estructurada de historial médico para consulta externa.
- **Calendario Mensual:** Vista rápida de cumplimiento terapéutico por días.

### Mejoras Técnicas & Estabilidad
- **Clean Architecture:** Desacoplamiento en capas de repositorios, casos de uso y servicios.
- **Patrón Result:** Manejo tipado de errores y estados de dosis estrictos.`
    },
    {
      tag_name: 'v2.20.2',
      name: 'MediTime 2.20.2 - Lanzamiento Base de la Aplicación',
      published_at: '2025-05-12T14:10:00Z',
      apk_url: 'https://github.com/JDkinior/MediTime/releases',
      body: `### Novedades Principales
- **Lanzamiento Oficial:** Primera versión estable de MediTime para Android.
- **Gestión de Recetas:** Registro de medicamentos, dosis, frecuencias y horarios diarios.
- **Notificaciones Locales:** Sistema inicial de avisos para tomas programadas.`
    }
  ];

  let currentReleases = FALLBACK_RELEASES;
  let activeVersionTag = 'v2.32.0';

  function renderChangelogSpotlight(latest) {
    if (!latest) return;
    const tag = latest.tag_name;
    const dateFormatted = formatSpanishDate(latest.published_at);
    const downloadUrl = latest.apk_url || `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;

    const tagElem = $('#spotlight-version-tag');
    if (tagElem) tagElem.textContent = tag;

    const dateElem = $('#spotlight-date-text');
    if (dateElem) {
      dateElem.innerHTML = `
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect width="18" height="18" x="3" y="4" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
        <span>${dateFormatted}</span>
      `;
    }

    const apkBtn = $('#spotlight-apk-btn');
    if (apkBtn) {
      apkBtn.href = downloadUrl;
      apkBtn.innerHTML = `
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        <span>Descargar APK (${tag})</span>
      `;
    }

    // Actualizar badges globales
    const heroVersionBadge = $('#hero-version-badge');
    const heroDownloadBtn = $('#hero-download-btn');
    const mainDownloadBtn = $('#main-download-btn');
    const latestVersionText = $('#latest-version-text');
    const downloadMetaVersion = $('#download-meta-version');

    if (heroVersionBadge) {
      heroVersionBadge.innerHTML = `
        <span class="hero-version-prefix">Versión ${tag} disponible · Con</span>
        <span class="hero-version-sr">Versión ${tag} disponible · Con IA y Modo Cuidador</span>
        <span class="modo-rotator" aria-hidden="true">
          <span class="modo-item modo-ia">IA</span>
          <span class="modo-item modo-cuidador">Modo Cuidador</span>
          <span class="modo-item modo-animales">Modo Animales</span>
</span>`;
      initHeroModeRotator();
    }
    if (heroDownloadBtn) {
      heroDownloadBtn.href = downloadUrl;
      heroDownloadBtn.setAttribute('title', `Descargar MediTime ${tag} (APK)`);
    }
    if (mainDownloadBtn) {
      mainDownloadBtn.href = downloadUrl;
      mainDownloadBtn.innerHTML = `<span>Descargar MediTime ${tag} (APK)</span> <span class="btn-icon" aria-hidden="true"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg></span>`;
    }
    if (latestVersionText) latestVersionText.textContent = `Última versión estable: ${tag}`;
    if (downloadMetaVersion) downloadMetaVersion.textContent = tag;
  }

  function renderChangelogHubList(releases, selectedTag) {
    const listContainer = $('#changelog-hub-list');
    if (!listContainer) return;
    listContainer.innerHTML = '';

    releases.forEach((rel, idx) => {
      const isSelected = selectedTag ? (rel.tag_name === selectedTag) : (idx === 0);
      const isLatest = idx === 0;
      const dateFormatted = formatSpanishDate(rel.published_at);

      let badgeClass = 'badge-stable';
      let badgeLabel = 'Estable';
      if (isLatest) { badgeClass = 'badge-latest'; badgeLabel = 'Última'; }
      else if (rel.tag_name.includes('patch') || rel.tag_name.includes('26.5')) { badgeClass = 'badge-patch'; badgeLabel = 'Parche'; }
      else if (idx === releases.length - 1) { badgeClass = 'badge-base'; badgeLabel = 'Base'; }

      const cleanSnippet = (rel.body || '').replace(/###|##|#|\*\*|\*|`/g, '').split('\n').filter(l => l.trim().length > 5)[0] || 'Mejoras y actualizaciones generales.';

      const btn = document.createElement('button');
      btn.className = `hub-version-item ${isSelected ? 'active' : ''}`;
      btn.setAttribute('data-version', rel.tag_name);
      btn.setAttribute('role', 'tab');
      btn.setAttribute('aria-selected', String(isSelected));
      btn.innerHTML = `
        <div class="hub-item-top">
          <span class="hub-item-tag">${rel.tag_name}</span>
          <span class="hub-item-badge ${badgeClass}">${badgeLabel}</span>
        </div>
        <div class="hub-item-date">${dateFormatted}</div>
        <div class="hub-item-snippet">${cleanSnippet}</div>
      `;

      btn.addEventListener('click', () => {
        $$('.hub-version-item', listContainer).forEach(b => {
          b.classList.remove('active');
          b.setAttribute('aria-selected', 'false');
        });
        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');
        activeVersionTag = rel.tag_name;
        renderChangelogHubDetail(rel);
      });

      listContainer.appendChild(btn);
    });

    const countBadge = $('#hub-version-count-badge');
    if (countBadge) {
      countBadge.textContent = `${releases.length} versión${releases.length !== 1 ? 'es' : ''} disponible${releases.length !== 1 ? 's' : ''}`;
    }
  }

  function renderChangelogHubDetail(release) {
    const detailPanel = $('#changelog-hub-detail');
    if (!detailPanel || !release) return;

    const titleElem = $('#detail-version-title');
    const badgeElem = $('#detail-version-badge');
    const dateElem = $('#detail-version-date');
    const apkBtn = $('#detail-apk-download-btn');
    const bodyElem = $('#detail-version-body');
    const ghLink = $('#detail-github-release-link');

    const isLatest = release.tag_name === (currentReleases[0] ? currentReleases[0].tag_name : 'v2.32.0');
    const dateFormatted = formatSpanishDate(release.published_at);
    const parsedHtml = formatMarkdownBody(release.body || 'Sin notas de versión disponibles.');
    const downloadUrl = release.apk_url || `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/tag/${release.tag_name}`;
    const ghUrl = `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/tag/${release.tag_name}`;

    if (titleElem) titleElem.textContent = release.tag_name;
    if (badgeElem) {
      badgeElem.className = `hub-item-badge ${isLatest ? 'badge-latest' : 'badge-stable'}`;
      badgeElem.textContent = isLatest ? 'Última Versión Oficial' : 'Versión Estable';
    }
    if (dateElem) {
      dateElem.innerHTML = `
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect width="18" height="18" x="3" y="4" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
        <span>Publicado el ${dateFormatted}</span>
      `;
    }
    if (apkBtn) {
      apkBtn.href = downloadUrl;
      apkBtn.innerHTML = `
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        <span>Descargar APK (${release.tag_name})</span>
      `;
    }
    if (bodyElem) {
      bodyElem.innerHTML = parsedHtml;
    }
    if (ghLink) {
      ghLink.href = ghUrl;
    }
  }

  function initChangelogSearch() {
    const searchInput = $('#changelog-search-input');
    if (!searchInput) return;

    searchInput.addEventListener('input', () => {
      const q = searchInput.value.trim().toLowerCase();
      if (!q) {
        renderChangelogHubList(currentReleases, activeVersionTag);
        const match = currentReleases.find(r => r.tag_name === activeVersionTag) || currentReleases[0];
        renderChangelogHubDetail(match);
        return;
      }

      const filtered = currentReleases.filter(r => {
        const tag = (r.tag_name || '').toLowerCase();
        const name = (r.name || '').toLowerCase();
        const body = (r.body || '').toLowerCase();
        return tag.includes(q) || name.includes(q) || body.includes(q);
      });

      renderChangelogHubList(filtered, filtered[0] ? filtered[0].tag_name : null);
      if (filtered.length > 0) {
        renderChangelogHubDetail(filtered[0]);
      } else {
        const bodyElem = $('#detail-version-body');
        if (bodyElem) {
          bodyElem.innerHTML = `
            <div style="padding: 40px; text-align: center; color: var(--text-muted);">
              <p style="font-size: 1.1rem; margin-bottom: 8px;"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block; vertical-align:middle; margin-right:6px;"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>No se encontraron versiones ni cambios para "<strong>${q}</strong>".</p>
              <p style="font-size: 0.9rem;">Prueba con otros términos como: <em>alarma, IA, cuidador, PDF, calendario</em>.</p>
            </div>
          `;
        }
      }
    });
  }

  function initModesDeepSwitcher() {
    const tabBtns = $$('.mode-deep-tab-btn');
    const panelCaregiver = $('#panel-deep-caregiver');
    const panelPets = $('#panel-deep-pets');

    if (tabBtns.length === 0 || !panelCaregiver || !panelPets) return;

    function applyModeTheme(mode) {
      document.body.classList.toggle('modes-theme-caregiver', mode === 'caregiver');
      document.body.classList.toggle('modes-theme-pets', mode === 'pets');
    }

    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const target = btn.getAttribute('data-target-mode');
        tabBtns.forEach(b => {
          b.classList.remove('active');
          b.setAttribute('aria-selected', 'false');
        });
        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');
        applyModeTheme(target);

        if (target === 'caregiver') {
          panelCaregiver.style.display = 'block';
          panelCaregiver.classList.add('active');
          panelPets.style.display = 'none';
          panelPets.classList.remove('active');
        } else {
          panelCaregiver.style.display = 'none';
          panelCaregiver.classList.remove('active');
          panelPets.style.display = 'block';
          panelPets.classList.add('active');
        }
      });
    });
  }

  async function loadGitHubReleases() {
    // 1. Renderizado instantáneo (0ms) con datos precompilados de MediTime
    renderChangelogSpotlight(FALLBACK_RELEASES[0]);
    renderChangelogHubList(FALLBACK_RELEASES, 'v2.32.0');
    renderChangelogHubDetail(FALLBACK_RELEASES[0]);

    let releases = null;

    // 2. Intentar leer caché local
    try {
      const cached = localStorage.getItem(RELEASES_CACHE_KEY);
      if (cached) {
        const parsed = JSON.parse(cached);
        if (Date.now() - parsed.timestamp < CACHE_TTL_MS && Array.isArray(parsed.data)) {
          releases = parsed.data;
        }
      }
    } catch (e) {
      console.warn('Error al leer caché de releases:', e);
    }

    // 3. Si no hay caché, consultar GitHub API
    if (!releases) {
      try {
        const res = await fetch(`https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases?per_page=8`, {
          headers: { 'Accept': 'application/vnd.github+json' }
        });
        if (res.ok) {
          const data = await res.json();
          if (Array.isArray(data) && data.length > 0) {
            releases = data.map(r => {
              const apk = (r.assets || []).find(a => /\.apk$/i.test(a.name));
              return {
                tag_name: r.tag_name,
                name: r.name || r.tag_name,
                published_at: r.published_at,
                body: r.body,
                apk_url: apk ? apk.browser_download_url : r.html_url,
                is_apk: Boolean(apk)
              };
            });
            localStorage.setItem(RELEASES_CACHE_KEY, JSON.stringify({
              timestamp: Date.now(),
              data: releases
            }));
          }
        }
      } catch (err) {
        console.warn('No se pudo conectar a GitHub API, usando datos locales:', err);
      }
    }

    if (releases && releases.length > 0) {
      currentReleases = releases;
      renderChangelogSpotlight(currentReleases[0]);
      renderChangelogHubList(currentReleases, activeVersionTag);
      const activeRel = currentReleases.find(r => r.tag_name === activeVersionTag) || currentReleases[0];
      renderChangelogHubDetail(activeRel);
    }
  }

  function formatSpanishDate(dateStr) {
    if (!dateStr) return 'Reciente';
    try {
      const date = new Date(dateStr);
      return date.toLocaleDateString('es-ES', {
        day: 'numeric',
        month: 'long',
        year: 'numeric'
      });
    } catch {
      return dateStr.split('T')[0] || dateStr;
    }
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function renderInline(text) {
    let html = escapeHtml(text);
    // Imágenes ![alt](url)
    html = html.replace(/!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g, (m, alt, src) => `<img src="${src}" alt="${alt}" loading="lazy" />`);
    // Enlaces [texto](url)
    html = html.replace(/\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g, (m, label, href) => `<a href="${href}" target="_blank" rel="noopener noreferrer">${label}</a>`);
    // Código en línea `code`
    html = html.replace(/`([^`]+)`/g, (m, code) => `<code>${code}</code>`);
    // Negritas
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    // Cursiva *texto* (estilo GitHub)
    html = html.replace(/(^|[\s(])\*([^*\n]+)\*/g, '$1<em>$2</em>');
    return html;
  }

  function buildMarkdownListTree(flatItems) {
    const root = [];
    const stack = [{ indent: -1, children: root }];
    flatItems.forEach(item => {
      while (stack.length > 1 && stack[stack.length - 1].indent >= item.indent) {
        stack.pop();
      }
      const parent = stack[stack.length - 1];
      const node = {
        content: item.content,
        ordered: item.ordered,
        start: item.start,
        task: item.task,
        children: []
      };
      parent.children.push(node);
      stack.push({ indent: item.indent, children: node.children });
    });
    return root;
  }

  function renderMarkdownListNodes(nodes) {
    if (!nodes.length) return '';
    const first = nodes[0];
    const tag = first.ordered ? 'ol' : 'ul';
    const start = first.ordered && first.start > 1 ? ` start="${first.start}"` : '';
    let html = `<${tag}${start}>`;
    nodes.forEach(node => {
      const marker = node.task
        ? `<span class="task-marker ${node.task.checked ? 'task-checked' : ''}" aria-hidden="true">${node.task.checked ? '&#x2611;' : '&#x2610;'}</span>`
        : '';
      let li = `<li>${marker}${renderInline(node.content)}`;
      if (node.children.length) {
        li += renderMarkdownListNodes(node.children);
      }
      li += '</li>';
      html += li;
    });
    return html + `</${tag}>`;
  }

  function formatMarkdownBody(md) {
    if (!md) return '';
    const lines = md.replace(/\r\n?/g, '\n').split('\n');
    const blocks = [];
    let pendingList = null;
    let i = 0;

    const flushList = () => {
      if (pendingList) {
        const tree = buildMarkdownListTree(pendingList.items);
        blocks.push({ type: 'list', nodes: tree });
        pendingList = null;
      }
    };

    while (i < lines.length) {
      const raw = lines[i];

      // Línea en blanco: cierra listas abiertas
      if (!raw.trim()) {
        flushList();
        i++;
        continue;
      }

      // Bloque de código ```
      if (/^\s*```/.test(raw)) {
        flushList();
        const codeLines = [];
        i++;
        while (i < lines.length && !/^\s*```/.test(lines[i])) {
          codeLines.push(lines[i]);
          i++;
        }
        i++;
        blocks.push({ type: 'code', text: codeLines.join('\n') });
        continue;
      }

      // Encabezados #, ##, ### ...
      const heading = raw.match(/^(#{1,6})\s+(.*)$/);
      if (heading) {
        flushList();
        blocks.push({ type: 'heading', level: heading[1].length, content: heading[2] });
        i++;
        continue;
      }

      // Línea horizontal ---
      if (/^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(raw)) {
        flushList();
        blocks.push({ type: 'hr' });
        i++;
        continue;
      }

      // Cita >
      if (/^\s*>\s?/.test(raw)) {
        flushList();
        const quote = [];
        while (i < lines.length && /^\s*>\s?/.test(lines[i])) {
          quote.push(lines[i].replace(/^\s*>\s?/, ''));
          i++;
        }
        blocks.push({ type: 'quote', content: quote.join(' ') });
        continue;
      }

      // Elemento de lista (-, *, +, 1.)
      const listItem = raw.match(/^(\s*)([-*+]|\d+[.)])\s+(.*)$/);
      if (listItem) {
        if (!pendingList) pendingList = { items: [] };
        const indent = listItem[1].replace(/\t/g, '    ').length;
        const marker = listItem[2];
        let content = listItem[3];
        const ordered = /^\d/.test(marker);
        const start = ordered ? (parseInt(marker, 10) || 1) : 1;

        let task = null;
        const taskMatch = content.match(/^\[([ xX])\]\s+(.*)$/);
        if (taskMatch) {
          task = { checked: taskMatch[1].toLowerCase() === 'x' };
          content = taskMatch[2];
        }

        pendingList.items.push({ indent, ordered, start, content, task });

        // Líneas de continuación del mismo elemento (texto envuelto)
        i++;
        while (i < lines.length) {
          const next = lines[i];
          if (!next.trim()) break;
          if (/^(#{1,6})\s+/.test(next) || /^\s*```/.test(next) || /^\s*>\s?/.test(next) ||
              /^\s*[-*+] /.test(next) || /^\s*\d+[.)] /.test(next)) break;
          const item = pendingList.items[pendingList.items.length - 1];
          item.content += `<br>${next.trim()}`;
          i++;
        }
        continue;
      }

      // Párrafo
      flushList();
      const para = [];
      while (i < lines.length) {
        const next = lines[i];
        if (!next.trim()) break;
        if (/^(#{1,6})\s+/.test(next) || /^\s*```/.test(next) || /^\s*[-*+] /.test(next) ||
            /^\s*\d+[.)] /.test(next) || /^\s*>\s?/.test(next) ||
            /^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(next)) break;
        para.push(next.trim());
        i++;
      }
      blocks.push({ type: 'paragraph', content: para.join(' ') });
    }
    flushList();

    return blocks.map(block => {
      switch (block.type) {
        case 'heading': {
          const level = Math.min(6, block.level);
          return `<h${level}>${renderInline(block.content)}</h${level}>`;
        }
        case 'paragraph':
          return `<p>${renderInline(block.content)}</p>`;
        case 'list':
          return renderMarkdownListNodes(block.nodes);
        case 'code':
          return `<pre class="markdown-code"><code>${escapeHtml(block.text)}</code></pre>`;
        case 'quote':
          return `<blockquote class="markdown-quote"><p>${renderInline(block.content)}</p></blockquote>`;
        case 'hr':
          return '<hr class="markdown-hr" />';
        default:
          return '';
      }
    }).join('\n');
  }

  loadGitHubReleases();
  initChangelogSearch();
  initModesDeepSwitcher();

  // --- 4. INTERACTIVE APP SHOWCASE (VIDEO SLIDER & GESTURES) ---
  function initShowcaseSlider() {
    const showcaseScreen = $('#showcase-screen');
    const track = $('#showcase-slider-track');
    const tabs = $$('.showcase-tab');
    const dots = $$('.swipe-dot');
    const slides = $$('.showcase-slide');
    const videos = $$('.showcase-video');

    if (!showcaseScreen || !track || slides.length === 0) return;

    let currentIndex = 0;
    const totalSlides = slides.length;

    // Helper: update active video playback
    function syncVideos(activeIndex) {
      videos.forEach((video, idx) => {
        if (idx === activeIndex) {
          const playPromise = video.play();
          if (playPromise !== undefined) {
            playPromise.catch(() => {
              // Autoplay policy fallback
            });
          }
        } else {
          video.pause();
        }
      });
    }

    function goToSlide(index, animate = true) {
      if (index < 0) index = 0;
      if (index >= totalSlides) index = totalSlides - 1;
      currentIndex = index;

      if (!animate) {
        track.classList.add('no-transition');
      } else {
        track.classList.remove('no-transition');
      }

      const offsetPercent = -(currentIndex * (100 / totalSlides));
      track.style.transform = `translateX(${offsetPercent}%)`;

      // Update tabs state
      tabs.forEach((tab, i) => {
        const isActive = i === currentIndex;
        tab.classList.toggle('active', isActive);
        tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
      });

      // Update dots state
      dots.forEach((dot, i) => {
        dot.classList.toggle('active', i === currentIndex);
      });

      // Update slides active state
      slides.forEach((slide, i) => {
        slide.classList.toggle('active', i === currentIndex);
      });

      syncVideos(currentIndex);
    }

    // Tab click listeners
    tabs.forEach((tab, index) => {
      tab.addEventListener('click', () => {
        goToSlide(index);
      });
    });

    // Dot click listeners
    dots.forEach((dot, index) => {
      dot.addEventListener('click', () => {
        goToSlide(index);
      });
    });

    // Touch and swipe gesture handling
    let touchStartX = 0;
    let touchStartY = 0;
    let touchCurrentX = 0;
    let isTouching = false;
    let isHorizontalSwipe = null;

    showcaseScreen.addEventListener('touchstart', (e) => {
      if (e.touches.length !== 1) return;
      isTouching = true;
      isHorizontalSwipe = null;
      touchStartX = e.touches[0].clientX;
      touchStartY = e.touches[0].clientY;
      touchCurrentX = touchStartX;
    }, { passive: true });

    showcaseScreen.addEventListener('touchmove', (e) => {
      if (!isTouching || e.touches.length !== 1) return;
      touchCurrentX = e.touches[0].clientX;
      const diffX = touchCurrentX - touchStartX;
      const diffY = e.touches[0].clientY - touchStartY;

      if (isHorizontalSwipe === null) {
        if (Math.abs(diffX) > 8 || Math.abs(diffY) > 8) {
          isHorizontalSwipe = Math.abs(diffX) > Math.abs(diffY);
        }
      }

      if (isHorizontalSwipe) {
        if (e.cancelable) e.preventDefault();
        const screenWidth = showcaseScreen.clientWidth || 1;
        const dragPercent = (diffX / screenWidth) * (100 / totalSlides);
        const basePercent = -(currentIndex * (100 / totalSlides));
        track.classList.add('no-transition');
        track.style.transform = `translateX(${basePercent + dragPercent}%)`;
      }
    }, { passive: false });

    const endTouch = () => {
      if (!isTouching) return;
      isTouching = false;
      track.classList.remove('no-transition');

      if (isHorizontalSwipe) {
        const diffX = touchCurrentX - touchStartX;
        const threshold = 35;

        if (diffX < -threshold && currentIndex < totalSlides - 1) {
          goToSlide(currentIndex + 1);
        } else if (diffX > threshold && currentIndex > 0) {
          goToSlide(currentIndex - 1);
        } else {
          goToSlide(currentIndex);
        }
      } else {
        goToSlide(currentIndex);
      }
      isHorizontalSwipe = null;
    };

    showcaseScreen.addEventListener('touchend', endTouch, { passive: true });
    showcaseScreen.addEventListener('touchcancel', endTouch, { passive: true });

    // Desktop mouse drag support
    let isMouseDown = false;
    let mouseStartX = 0;
    let mouseCurrentX = 0;

    showcaseScreen.addEventListener('mousedown', (e) => {
      if (e.button !== 0) return;
      isMouseDown = true;
      mouseStartX = e.clientX;
      mouseCurrentX = mouseStartX;
      track.classList.add('no-transition');
    });

    window.addEventListener('mousemove', (e) => {
      if (!isMouseDown) return;
      mouseCurrentX = e.clientX;
      const diffX = mouseCurrentX - mouseStartX;
      const screenWidth = showcaseScreen.clientWidth || 1;
      const dragPercent = (diffX / screenWidth) * (100 / totalSlides);
      const basePercent = -(currentIndex * (100 / totalSlides));
      track.style.transform = `translateX(${basePercent + dragPercent}%)`;
    });

    window.addEventListener('mouseup', () => {
      if (!isMouseDown) return;
      isMouseDown = false;
      track.classList.remove('no-transition');
      const diffX = mouseCurrentX - mouseStartX;
      const threshold = 35;

      if (diffX < -threshold && currentIndex < totalSlides - 1) {
        goToSlide(currentIndex + 1);
      } else if (diffX > threshold && currentIndex > 0) {
        goToSlide(currentIndex - 1);
      } else {
        goToSlide(currentIndex);
      }
    });

    // Pause videos when offscreen, resume when visible
    if ('IntersectionObserver' in window) {
      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            syncVideos(currentIndex);
          } else {
            videos.forEach(v => v.pause());
          }
        });
      }, { threshold: 0.2 });

      observer.observe(showcaseScreen);
    } else {
      syncVideos(0);
    }

    goToSlide(0, false);
  }

  initShowcaseSlider();

  // --- 5. MIDI AI CHATBOT INTERACTIVE SIMULATOR ---
  const midiAvatarImgs = $$('.midi-avatar-dynamic');
  const chatMessages = $('#chat-messages');
  const chatInput = $('#chat-user-input');
  const chatSendBtn = $('#chat-send-btn');
  const promptChips = $$('.prompt-chip');

  // Avatar natural blinking timer (2.2s - 5.5s aleatorio)
  function setupMidiBlink() {
    function blink() {
      midiAvatarImgs.forEach(img => {
        img.src = 'images/midi_blink.png';
      });
      setTimeout(() => {
        midiAvatarImgs.forEach(img => {
          img.src = 'images/midi_open.png';
        });
        const nextBlink = Math.random() * 3300 + 2200;
        setTimeout(blink, nextBlink);
      }, 180);
    }
    setTimeout(blink, 2500);
  }
  setupMidiBlink();

  // Knowledge base simulada con el tono y pautas clínicas reales de Midi
  const MIDI_KNOWLEDGE = [
    {
      keywords: ['omeprazol', 'ayuna', 'ayunas', 'estomago', 'protector'],
      response: '¡Hola! El omeprazol es un inhibidor de la bomba de protones y debe tomarse preferiblemente en ayunas, unos 30 a 60 minutos antes del desayuno con un vaso completo de agua. Esto asegura que alcance su máxima concentración en sangre justo cuando las células del estómago comienzan a activarse para digerir los alimentos.'
    },
    {
      keywords: ['olvide', 'olvido', 'dosis', 'salte', 'se me paso'],
      response: 'Si olvidaste una dosis, tómala tan pronto como lo recuerdes. Sin embargo, si ya está muy cerca de tu siguiente dosis programada, omite la dosis olvidada y continúa con tu horario regular. Nota importante: Nunca tomes dos dosis juntas para compensar.'
    },
    {
      keywords: ['cuidador', 'caregiver', 'papa', 'hijo', 'familiar', 'dependiente', 'abuelo'],
      response: 'El **Modo Cuidador** de MediTime te permite gestionar los esquemas terapéuticos de tus dependientes (hijos, padres o personas a tu cargo) con una interfaz diferenciada en tono morado pastel, perfiles individuales, recordatorios dedicados y reportes clínicos listos para el médico.'
    },
    {
      keywords: ['mascota', 'animal', 'perro', 'gato', 'veterinaria', 'animales'],
      response: '¡Así es! MediTime cuenta con un **Modo Animales (Veterinaria)** con paleta verde menta, diseñado exclusivamente para pautas de desparasitación, antibióticos y tratamientos de mascotas con intervalos personalizados.'
    },
    {
      keywords: ['internet', 'offline', 'sin conexion', 'datos', 'wifi', 'funciona'],
      response: 'MediTime funciona con total independencia offline. Gracias al motor nativo `android_alarm_manager_plus`, las alarmas de tus medicamentos sonarán puntualmente aunque no tengas internet, con la pantalla apagada o incluso tras reiniciar el dispositivo. Cuando vuelvas a tener red, se sincroniza en la nube.'
    },
    {
      keywords: ['premium', 'precio', 'plan', 'gratis', 'pago', 'costo'],
      response: 'MediTime ofrece un **Nivel Gratuito** sin anuncios para hasta 3 tratamientos activos y 1 perfil dependiente con todas las alarmas de hardware. Con **MediTime Premium** obtienes tratamientos y perfiles ilimitados, generación sin límites de reportes PDF para tu médico y widgets interactivos para tu pantalla de inicio.'
    },
    {
      keywords: ['quien eres', 'quien sos', 'identidad', 'valores'],
      response: 'Soy Midi, el asistente virtual bilingüe de MediTime. Soy LIBRE, AUTÓNOMO Y RESPONSABLE a través del diálogo y la construcción, como ideal regulativo; me dirijo, controlo y dicto mis propias leyes.'
    }
  ];

  function getMidiResponse(userText) {
    const clean = userText.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    for (const item of MIDI_KNOWLEDGE) {
      if (item.keywords.some(k => clean.includes(k))) {
        return item.response;
      }
    }
    return `Como asistente de MediTime, puedo ayudarte a organizar tus tomas, resolver dudas sobre pautas de administración o recordarte cómo configurar tus alarmas y perfiles en la app. Recuerda siempre seguir las indicaciones de tu médico o especialista tratante.`;
  }

  function addChatMessage(text, sender = 'bot') {
    if (!chatMessages) return;

    const msg = document.createElement('div');
    msg.className = `message ${sender}`;
    const timeStr = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    if (sender === 'bot') {
      msg.innerHTML = `
        <img src="images/midi_open.png" alt="Midi" class="message-avatar midi-avatar-dynamic" />
        <div>
          <div class="message-bubble">${text}</div>
          <div class="message-time">${timeStr}</div>
        </div>
      `;
    } else {
      msg.innerHTML = `
        <div>
          <div class="message-bubble">${text}</div>
          <div class="message-time">${timeStr}</div>
        </div>
      `;
    }

    chatMessages.appendChild(msg);
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }

  function showTypingIndicator() {
    const typing = document.createElement('div');
    typing.className = 'message bot typing-msg';
    typing.id = 'midi-typing-indicator';
    typing.innerHTML = `
      <img src="images/midi_open.png" alt="Midi" class="message-avatar midi-avatar-dynamic" />
      <div class="message-bubble">
        <div class="typing-dots">
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
          <span class="typing-dot"></span>
        </div>
      </div>
    `;
    chatMessages.appendChild(typing);
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }

  function removeTypingIndicator() {
    const typing = $('#midi-typing-indicator');
    if (typing) typing.remove();
  }

  function handleUserMessage(text) {
    if (!text || !text.trim()) return;
    const cleanText = text.trim();

    addChatMessage(cleanText, 'user');
    if (chatInput) chatInput.value = '';

    showTypingIndicator();

    setTimeout(() => {
      removeTypingIndicator();
      const answer = getMidiResponse(cleanText);
      addChatMessage(answer, 'bot');
    }, 650);
  }

  if (chatSendBtn && chatInput) {
    chatSendBtn.addEventListener('click', () => handleUserMessage(chatInput.value));
    chatInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') handleUserMessage(chatInput.value);
    });
  }

  promptChips.forEach(chip => {
    chip.addEventListener('click', () => {
      const question = chip.textContent.trim();
      handleUserMessage(question);
    });
  });

  // --- 6. FAQ ACCORDION ---
  const faqItems = $$('.faq-item');
  faqItems.forEach(item => {
    const trigger = $('.faq-trigger', item);
    if (!trigger) return;

    trigger.addEventListener('click', () => {
      const isActive = item.classList.contains('active');
      faqItems.forEach(other => other.classList.remove('active'));
      if (!isActive) {
        item.classList.add('active');
      }
    });
  });

  // --- 7. CONTACT FORM AJAX SUBMISSION ---
  const contactForm = $('#contact-form');
  const formStatus = $('#form-status');

  if (contactForm) {
    contactForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const submitBtn = $('button[type="submit"]', contactForm);
      const originalText = submitBtn ? submitBtn.textContent : 'Enviar';

      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'Enviando mensaje...';
      }

      try {
        const formData = new FormData(contactForm);
        const res = await fetch(contactForm.action, {
          method: 'POST',
          body: formData,
          headers: { 'Accept': 'application/json' }
        });

        if (res.ok) {
          if (formStatus) {
            formStatus.className = 'form-status success';
            formStatus.textContent = '¡Muchas gracias! Tu mensaje ha sido enviado exitosamente al equipo de MediTime.';
            formStatus.style.display = 'block';
          }
          contactForm.reset();
        } else {
          throw new Error('Error al enviar formulario');
        }
      } catch (err) {
        if (formStatus) {
          formStatus.className = 'form-status error';
          formStatus.textContent = 'Hubo un problema al enviar tu mensaje. Por favor intenta de nuevo o escríbenos por GitHub.';
          formStatus.style.display = 'block';
        }
      } finally {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.textContent = originalText;
        }
      }
    });
  }

  // --- 8. SMOOTH SCROLL WITH OFFSET ---
  $$('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (!targetId || targetId === '#') return;

      const targetElem = $(targetId);
      if (targetElem) {
        e.preventDefault();
        scrollToTargetSection(targetElem, !reducedPageMotion);
        if (history.pushState) {
          history.pushState(null, '', targetId);
        } else {
          window.location.hash = targetId;
        }
      }
    });
  });

  // Keep navigation active indicators synced with scroll and section visibility
  function initScrollSpy() {
    const navLinks = $$('.nav-desktop .nav-link');
    if (!navLinks.length) return;

    const watchedSections = ['#pricing', '#about'].map(id => $(id)).filter(Boolean);
    const heroSection = $('#hero');

    function syncNav() {
      const scrollPos = window.scrollY + 140;
      let activeId = '';

      for (let i = watchedSections.length - 1; i >= 0; i--) {
        const sec = watchedSections[i];
        if (sec.offsetTop <= scrollPos) {
          activeId = '#' + sec.id;
          break;
        }
      }

      if (!activeId && heroSection && window.scrollY < 450) {
        activeId = 'index.html';
      }

      if (activeId) {
        navLinks.forEach(link => {
          const href = link.getAttribute('href') || '';
          if (href === activeId || (activeId === 'index.html' && (href === 'index.html' || href === '#hero'))) {
            link.classList.add('active');
          } else {
            link.classList.remove('active');
          }
        });
      }
    }

    window.addEventListener('scroll', () => {
      requestAnimationFrame(syncNav);
    }, { passive: true });

    syncNav();
  }

  initScrollSpy();

  // --- 9. PWA SERVICE WORKER REGISTRATION ---
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('./sw.js').then(registration => {
        registration.update();
      }).catch(err => {
        console.log('ServiceWorker registration failed: ', err);
      });
    });
  }

  // --- 10. HERO INTERACTIVE PARTICLES SYSTEM ---
  function initHeroParticles() {
    const canvas = $('#hero-particles');
    const heroSection = $('#hero');
    if (!canvas || !heroSection) return;
    if (window.innerWidth < 768) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = 0;
    let height = 0;
    let animationFrameId = null;
    let isVisible = true;
    let mouse = { x: -1000, y: -1000, radius: 140 };

    let particles = [];
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function getThemeColors() {
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      if (isDark) {
        return {
          nodes: [
            'rgba(59, 130, 246, 0.8)',   // Primary electric blue
            'rgba(56, 189, 248, 0.75)',  // Cyan bio-pulse
            'rgba(168, 85, 247, 0.7)',   // Lavender Caregiver
            'rgba(52, 211, 153, 0.65)'   // Mint Health
          ],
          lineBase: 'rgba(59, 130, 246,',
          mouseLineBase: 'rgba(56, 189, 248,'
        };
      } else {
        return {
          nodes: [
            'rgba(0, 74, 198, 0.5)',    // Deep trust blue
            'rgba(14, 165, 233, 0.45)',  // Cyan accent
            'rgba(124, 58, 237, 0.4)',   // Purple Caregiver
            'rgba(5, 150, 105, 0.4)'    // Emerald
          ],
          lineBase: 'rgba(0, 74, 198,',
          mouseLineBase: 'rgba(14, 165, 233,'
        };
      }
    }

    let colors = getThemeColors();

    function resize() {
      if (window.innerWidth < 768) {
        if (animationFrameId) {
          cancelAnimationFrame(animationFrameId);
          animationFrameId = null;
        }
        ctx.clearRect(0, 0, width, height);
        return;
      }

      const newWidth = heroSection.offsetWidth;
      const newHeight = heroSection.offsetHeight;
      if (width === newWidth && Math.abs(height - newHeight) < 80) return;

      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = newWidth;
      height = newHeight;
      canvas.width = width * dpr;
      canvas.height = height * dpr;
      canvas.style.width = width + 'px';
      canvas.style.height = height + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      createParticles();
    }

    class Particle {
      constructor() {
        this.reset(true);
      }

      reset(initial = false) {
        this.x = initial ? Math.random() * width : (Math.random() > 0.5 ? 0 : width);
        this.y = initial ? Math.random() * height : Math.random() * height;
        const speed = (Math.random() * 0.4 + 0.18) * (prefersReducedMotion ? 0.05 : 1);
        const angle = Math.random() * Math.PI * 2;
        this.vx = Math.cos(angle) * speed;
        this.vy = Math.sin(angle) * speed;
        this.radius = Math.random() * 2 + 1.2;
        this.baseRadius = this.radius;
        this.color = colors.nodes[Math.floor(Math.random() * colors.nodes.length)];
        this.pulseSpeed = Math.random() * 0.02 + 0.01;
        this.pulseAngle = Math.random() * Math.PI * 2;
      }

      update() {
        this.x += this.vx;
        this.y += this.vy;

        if (this.x < -10) this.x = width + 10;
        if (this.x > width + 10) this.x = -10;
        if (this.y < -10) this.y = height + 10;
        if (this.y > height + 10) this.y = -10;

        this.pulseAngle += this.pulseSpeed;
        this.radius = this.baseRadius + Math.sin(this.pulseAngle) * 0.5;

        // Interacción suave con mouse
        const dx = mouse.x - this.x;
        const dy = mouse.y - this.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < mouse.radius) {
          const force = (mouse.radius - dist) / mouse.radius;
          const angle = Math.atan2(dy, dx);
          this.x -= Math.cos(angle) * force * 1.5;
          this.y -= Math.sin(angle) * force * 1.5;
        }
      }

      draw() {
        ctx.beginPath();
        ctx.arc(this.x, this.y, Math.max(0.5, this.radius), 0, Math.PI * 2);
        ctx.fillStyle = this.color;
        ctx.fill();

        // Resplandor para partículas destacadas
        if (this.baseRadius > 2.0) {
          ctx.beginPath();
          ctx.arc(this.x, this.y, this.radius * 2.2, 0, Math.PI * 2);
          ctx.fillStyle = this.color.replace(/[\d\.]+\)$/, '0.14)');
          ctx.fill();
        }
      }
    }

    function createParticles() {
      const targetCount = Math.floor(Math.min(width / 18, 75));
      particles = [];
      for (let i = 0; i < targetCount; i++) {
        particles.push(new Particle());
      }
    }

    function drawLines() {
      const maxDistance = width < 600 ? 85 : 120;
      const len = particles.length;

      for (let i = 0; i < len; i++) {
        for (let j = i + 1; j < len; j++) {
          const dx = particles[i].x - particles[j].x;
          const dy = particles[i].y - particles[j].y;
          const dist = Math.sqrt(dx * dx + dy * dy);

          if (dist < maxDistance) {
            const alpha = (1 - dist / maxDistance) * 0.22;
            ctx.beginPath();
            ctx.moveTo(particles[i].x, particles[i].y);
            ctx.lineTo(particles[j].x, particles[j].y);
            ctx.strokeStyle = `${colors.lineBase} ${alpha})`;
            ctx.lineWidth = 1;
            ctx.stroke();
          }
        }

        // Conexión sutil al cursor
        const dxMouse = mouse.x - particles[i].x;
        const dyMouse = mouse.y - particles[i].y;
        const distMouse = Math.sqrt(dxMouse * dxMouse + dyMouse * dyMouse);
        if (distMouse < mouse.radius) {
          const alphaMouse = (1 - distMouse / mouse.radius) * 0.35;
          ctx.beginPath();
          ctx.moveTo(particles[i].x, particles[i].y);
          ctx.lineTo(mouse.x, mouse.y);
          ctx.strokeStyle = `${colors.mouseLineBase} ${alphaMouse})`;
          ctx.lineWidth = 1.2;
          ctx.stroke();
        }
      }
    }

    function animate() {
      if (!isVisible) return;
      ctx.clearRect(0, 0, width, height);

      particles.forEach(p => {
        p.update();
        p.draw();
      });

      drawLines();
      animationFrameId = requestAnimationFrame(animate);
    }

    heroSection.addEventListener('mousemove', (e) => {
      const rect = heroSection.getBoundingClientRect();
      mouse.x = e.clientX - rect.left;
      mouse.y = e.clientY - rect.top;
    });

    heroSection.addEventListener('mouseleave', () => {
      mouse.x = -1000;
      mouse.y = -1000;
    });

    const themeObserver = new MutationObserver(() => {
      colors = getThemeColors();
      particles.forEach(p => {
        p.color = colors.nodes[Math.floor(Math.random() * colors.nodes.length)];
      });
    });
    themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        isVisible = entry.isIntersecting;
        if (isVisible && !animationFrameId) {
          animate();
        } else if (!isVisible && animationFrameId) {
          cancelAnimationFrame(animationFrameId);
          animationFrameId = null;
        }
      });
    }, { threshold: 0.05 });
    observer.observe(heroSection);

    let resizeTimeout;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(resize, 150);
    });

    resize();
    animate();
  }

  initHeroParticles();

  // --- 10a-bis. HERO BADGE: ROTADOR DE MODOS ESTABLE ---
  let heroModeRotator = null;

  function initHeroModeRotator() {
    const badge = $('#hero-version-badge');
    const rotator = badge ? badge.querySelector('.modo-rotator') : null;
    const items = rotator ? Array.from(rotator.querySelectorAll('.modo-item')) : [];
    if (!rotator || items.length === 0) return;

    if (heroModeRotator && heroModeRotator.timer) clearInterval(heroModeRotator.timer);

    heroModeRotator = { rotator, items, currentIndex: 0 };

    const activate = (index) => {
      heroModeRotator.currentIndex = ((index % items.length) + items.length) % items.length;
      items.forEach((item, i) => item.classList.toggle('active', i === heroModeRotator.currentIndex));
    };

    activate(0);

    if (reducedPageMotion) return;

    heroModeRotator.timer = window.setInterval(() => activate(heroModeRotator.currentIndex + 1), 3000);
  }

  initHeroModeRotator();

  // --- 10b. FONDO ANIMADO PARA LAS SECCIONES OSCURAS ---
  function initSiteParticles() {
    const canvas = $('#site-particles');
    if (!canvas || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    // En pantallas móviles/táctiles pequeñas, no ejecutar el canvas de fondo completo para máximo rendimiento a 60-120fps
    if (window.innerWidth < 768) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = 0;
    let height = 0;
    let dots = [];
    let isRunning = true;
    let resizeTimer = null;

    const palette = () => document.documentElement.getAttribute('data-theme') === 'dark'
      ? ['rgba(59, 130, 246, 0.62)', 'rgba(56, 189, 248, 0.54)', 'rgba(168, 85, 247, 0.5)', 'rgba(52, 211, 153, 0.48)']
      : ['rgba(0, 74, 198, 0.24)', 'rgba(14, 165, 233, 0.22)', 'rgba(124, 58, 237, 0.2)', 'rgba(5, 150, 105, 0.2)'];

    function resize() {
      const newWidth = window.innerWidth;
      const newHeight = window.innerHeight;

      if (newWidth < 768) {
        isRunning = false;
        ctx.clearRect(0, 0, width, height);
        return;
      }

      // Evitar re-renderizado destructivo si solo varió la altura (ej. colapso de barras)
      if (width === newWidth && Math.abs(height - newHeight) < 80) return;

      isRunning = true;
      const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      width = newWidth;
      height = newHeight;
      canvas.width = width * dpr;
      canvas.height = height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      dots = Array.from({ length: Math.min(40, Math.max(16, Math.floor(width / 40))) }, () => ({
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 0.16,
        vy: (Math.random() - 0.5) * 0.16,
        radius: Math.random() * 1.3 + 0.6,
        color: palette()[Math.floor(Math.random() * 4)]
      }));
    }

    function render() {
      if (!isRunning) return;
      ctx.clearRect(0, 0, width, height);
      for (let i = 0; i < dots.length; i++) {
        const dot = dots[i];
        dot.x = (dot.x + dot.vx + width) % width;
        dot.y = (dot.y + dot.vy + height) % height;
        ctx.beginPath();
        ctx.arc(dot.x, dot.y, dot.radius, 0, Math.PI * 2);
        ctx.fillStyle = dot.color;
        ctx.fill();
        for (let j = i + 1; j < dots.length; j++) {
          const other = dots[j];
          const dx = dot.x - other.x;
          const dy = dot.y - other.y;
          const distance = Math.hypot(dx, dy);
          if (distance < 120) {
            ctx.beginPath();
            ctx.moveTo(dot.x, dot.y);
            ctx.lineTo(other.x, other.y);
            ctx.strokeStyle = `rgba(59, 130, 246, ${(1 - distance / 120) * 0.12})`;
            ctx.lineWidth = 0.6;
            ctx.stroke();
          }
        }
      }
      requestAnimationFrame(render);
    }

    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(resize, 180);
    }, { passive: true });

    new MutationObserver(resize).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    resize();
    render();
  }

  initSiteParticles();

  // --- 11. SCROLL PARALLAX ENGINE ---
  function initScrollParallax() {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    // Desactivar en pantallas móviles o táctiles para garantizar 60-120fps nativos en el scroll
    const isMobile = window.innerWidth < 768 || window.matchMedia('(pointer: coarse)').matches;
    if (isMobile) return;

    const parallaxElements = $$('[data-parallax]');
    if (parallaxElements.length === 0) return;

    let ticking = false;

    function updateParallax() {
      const viewportHeight = window.innerHeight;

      parallaxElements.forEach(el => {
        const speed = parseFloat(el.getAttribute('data-parallax') || '0.1');
        const rect = el.getBoundingClientRect();
        const elemCenter = rect.top + rect.height / 2;

        if (rect.top < viewportHeight + 200 && rect.bottom > -200) {
          const offset = (elemCenter - viewportHeight / 2) * speed;
          
          if (el.classList.contains('phone-mockup-frame')) {
            const tilt = Math.max(-5, Math.min(5, (elemCenter - viewportHeight / 2) * 0.008));
            el.style.transform = `translate3d(0, ${offset.toFixed(1)}px, 0) rotateY(${tilt.toFixed(2)}deg)`;
          } else {
            el.style.transform = `translate3d(0, ${offset.toFixed(1)}px, 0)`;
          }
        }
      });

      ticking = false;
    }

    window.addEventListener('scroll', () => {
      if (!ticking) {
        requestAnimationFrame(updateParallax);
        ticking = true;
      }
    }, { passive: true });

    updateParallax();
  }

  initScrollParallax();

  // --- 12. HIGH-PERFORMANCE SECTION ENTRANCE REVEAL ENGINE ---
  function initSectionRevealAnimations() {
    // En móviles o si el usuario prefiere movimiento reducido, revelar todo inmediatamente para evitar saltos y tirones al detener el scroll
    if (window.innerWidth < 768 || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      $$('.section-header').forEach(h => h.classList.add('revealed'));
      $$(
        '.features-grid, .showcase-container, .midi-grid, .modes-grid, .pricing-grid, ' +
        '.download-section, .faq-list, .team-grid, .about-section, .contact-section, ' +
        '.features-deep-section, .modes-deep-section, .changelog-section, .changelog-hub-section'
      ).forEach(el => el.classList.add('revealed'));
      $$(
        '.changelog-spotlight-card, .deep-card, .mode-deep-card, .changelog-hub-sidebar, .changelog-hub-detail-panel'
      ).forEach(item => item.classList.add('revealed'));
      return;
    }

    // Marcar encabezados de secciones para revelado
    $$('.section-header').forEach(header => {
      header.classList.add('reveal-header');
    });

    const revealSelectors = [
      '.reveal-header',
      '.features-grid',
      '.showcase-container',
      '.midi-grid',
      '.modes-grid',
      '.pricing-grid',
      '.download-section',
      '.faq-list',
      '.team-grid',
      '.about-section',
      '.contact-section',
      '.features-deep-section',
      '.modes-deep-section',
      '.changelog-section',
      '.changelog-hub-section'
    ];

    // IntersectionObserver fluido y eficiente: revela al entrar y permanece visible y estable
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const target = entry.target;
          target.classList.add('revealed');
          observer.unobserve(target);

          if (target.classList.contains('changelog-timeline')) {
            $$('.changelog-item', target).forEach(item => {
              item.classList.add('revealed');
            });
          }
        }
      });
    }, {
      threshold: 0.05,
      rootMargin: '0px 0px -40px 0px'
    });

    revealSelectors.forEach(sel => {
      $$(sel).forEach(el => observer.observe(el));
    });

    // Observar items dinámicos del Changelog si llegan por fetch posterior
    const changelogTimeline = $('#changelog-timeline');
    if (changelogTimeline) {
      const changelogObserver = new MutationObserver(() => {
        $$('.changelog-item', changelogTimeline).forEach(item => {
          item.classList.add('revealed');
        });
      });
      changelogObserver.observe(changelogTimeline, { childList: true });

      // Respaldo de seguridad: asegurarse de que el changelog sea visible tras 1s
      setTimeout(() => {
        $$('.changelog-item', changelogTimeline).forEach(item => {
          item.classList.add('revealed');
        });
      }, 1000);
    }
  }

  initSectionRevealAnimations();

  // --- 13. HERO PHONE AUTONOMOUS LOOP SIMULATOR ---
  function initPhoneHeroSimulator() {
    const screen = $('#sim-phone-screen');
    const scrollArea = $('#sim-app-scroll');
    if (!screen || !scrollArea) return;

    // Multi-screen Views
    const viewPlan = $('#sim-view-plan');
    const viewCalendar = $('#sim-view-calendar');
    const viewStats = $('#sim-view-stats');
    const viewAdd = $('#sim-view-add');
    const viewAssistant = $('#sim-view-assistant');

    // Bottom Navigation Tabs
    const tabPlan = $('#sim-tab-plan');
    const tabCalendar = $('#sim-tab-calendar');
    const tabStats = $('#sim-tab-stats');

    // Internal app elements
    const liveTime = $('#sim-live-time');
    const island = $('#sim-dynamic-island');
    const islandContent = $('#sim-island-content');
    const alarmBanner = $('#sim-alarm-banner');
    const btnAlarmTake = $('#sim-btn-alarm-take');

    // Summary Card & Alternating Faces
    const summaryCard = $('#sim-summary-card');
    const faceMetrics = $('#sim-face-metrics');
    const faceAi = $('#sim-face-ai');

    // Metrics
    const metricPending = $('#sim-metric-pending');
    const metricTaken = $('#sim-metric-taken');
    const metricAdherence = $('#sim-metric-adherence');

    // Doses list
    const doseCount = $('#sim-dose-count');
    const node1 = $('#sim-node-1');
    const node2 = $('#sim-node-2');
    const pill1 = $('#sim-pill-1');
    const card1 = $('#sim-dose-card-1');
    const doseNew = $('#sim-dose-new');

    // Bottom Sheet & FAB
    const fabAdd = $('#sim-fab-add');
    const bottomSheet = $('#sim-bottom-sheet');
    const sheetBackdrop = $('#sim-sheet-backdrop');
    const btnSaveRecipe = $('#sim-btn-save-recipe');

    let timeouts = [];

    function clearAllTimeouts() {
      timeouts.forEach(t => clearTimeout(t));
      timeouts = [];
    }

    function schedule(fn, ms) {
      const id = setTimeout(fn, ms);
      timeouts.push(id);
      return id;
    }

    function switchView(target) {
      if (screen) screen.classList.toggle('tour-subpage', target === 'add' || target === 'assistant');
      if (viewPlan) viewPlan.classList.toggle('active', target === 'plan');
      if (viewCalendar) viewCalendar.classList.toggle('active', target === 'calendar');
      if (viewStats) viewStats.classList.toggle('active', target === 'stats');
      if (viewAdd) viewAdd.classList.toggle('active', target === 'add');
      if (viewAssistant) viewAssistant.classList.toggle('active', target === 'assistant');
      if (target === 'calendar' && calendarGrid) { calendarExpanded=false; $('#sim-view-calendar .calendar-month-card')?.classList.remove('expanded'); collapseCalendarWeek(); }

      if (tabPlan) tabPlan.classList.toggle('active', target === 'plan');
      if (tabCalendar) tabCalendar.classList.toggle('active', target === 'calendar');
      if (tabStats) tabStats.classList.toggle('active', target === 'stats');
    }

    function updateLiveTime() {
      if (liveTime) {
        const now = new Date();
        const hours = String(now.getHours()).padStart(2, '0');
        const mins = String(now.getMinutes()).padStart(2, '0');
        liveTime.textContent = `${hours}:${mins}`;
      }
    }
    updateLiveTime();
    setInterval(updateLiveTime, 30000);

    // Reset components to initial clean morning state
    function resetSimulationState() {
      clearAllTimeouts();

      // Show Screen 1: Plan de Hoy
      switchView('plan');

      if (islandContent) {
        islandContent.innerHTML = '<span class="island-icon-alarm"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:middle;margin-right:4px;" aria-hidden="true"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg></span><span class="island-text">18:22 · Dosis lista</span>';
      }

      // Summary Card: show Metrics view, hide AI advice view
      if (summaryCard) summaryCard.classList.remove('ai-active');
      if (faceMetrics) {
        faceMetrics.className = 'sim-card-face sim-face-metrics active';
      }
      if (faceAi) {
        faceAi.className = 'sim-card-face sim-face-ai';
      }

      // Alarm & Island
      if (alarmBanner) alarmBanner.classList.remove('active');
      if (island) island.classList.remove('island-expanded');
      if (btnAlarmTake) btnAlarmTake.classList.remove('pressed');

      // Bottom Sheet & FAB
      if (bottomSheet) bottomSheet.classList.remove('active');
      if (sheetBackdrop) sheetBackdrop.classList.remove('active');
      if (fabAdd) fabAdd.classList.remove('pulse-glow', 'pressed');
      if (btnSaveRecipe) btnSaveRecipe.classList.remove('pressed');

      // Dose 1 reset to Pending
      if (pill1) {
        pill1.textContent = 'Pendiente';
        pill1.className = 'sim-status-pill pill-pending';
      }
      if (node1) {
        node1.className = 'sim-dose-node node-missed';
        node1.innerHTML = '<span>×</span>';
      }
      if (node2) {
        node2.className = 'sim-dose-node node-pending';
        node2.innerHTML = '';
      }
      if (card1) card1.classList.remove('highlight-card');

      // Metrics reset
      if (metricPending) {
        metricPending.textContent = '2';
        metricPending.classList.remove('pulse');
      }
      if (metricTaken) {
        metricTaken.textContent = '1';
        metricTaken.classList.remove('pulse');
      }
      if (metricAdherence) {
        metricAdherence.textContent = '67%';
        metricAdherence.classList.remove('pulse');
      }

      // New Dose reset
      if (doseNew) doseNew.classList.remove('revealed');
      if (doseCount) doseCount.textContent = '3 tomas';

      // Scroll to top
      if (scrollArea) scrollArea.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // Guided product tour: a person-like loop through the core MediTime flows.
    const addNameStep = $('#sim-add-step-name');
    const addDetailsStep = $('#sim-add-step-details');
    const addNameInput = $('#sim-new-med-name');
    const addNext = $('#sim-add-next');
    const progressScroll = $('#sim-view-stats .sim-progress-screen');
    const chatScroll = $('#sim-chat-scroll');
    const midiResponse = $('#sim-midi-response');
    const midiTyping = $('#sim-chat-typing');
    const midiResponseMarkup = midiResponse?.innerHTML || '';
    let calendarMonthIndex = 0;
    let calendarDay = 22;

    function animateAssistantReply() {
      if (!midiResponse) return;
      midiResponse.innerHTML=midiResponseMarkup;
      midiResponse.hidden=true;
      midiTyping?.removeAttribute('hidden');
      schedule(() => {
        midiResponse.hidden=false;
        midiResponse.classList.add('is-typing');
        const advice=midiResponse.querySelector('aside');
        const timestamp=midiResponse.querySelector(':scope > small');
        const adviceText=advice?.textContent || '';
        // The warning is its own visual block. Keep it out of the layout until
        // Midi reaches that part of the response instead of rendering an empty box.
        if (advice) {
          advice.hidden=true;
          advice.textContent='';
        }
        if (timestamp) timestamp.hidden=true;
        const walker=document.createTreeWalker(midiResponse,NodeFilter.SHOW_TEXT);
        const textNodes=[];
        while(walker.nextNode()) {
          const node=walker.currentNode;
          const value=node.nodeValue || '';
          if(value.trim()) { textNodes.push({node,value}); node.nodeValue=''; }
        }
        let nodeIndex=0,characterIndex=0;
        const finishReply=()=>{
          midiResponse.classList.remove('is-typing');
          if (timestamp) timestamp.hidden=false;
          if (midiTyping) midiTyping.hidden=true;
        };
        const typeAdvice=()=>{
          if (!advice) {
            finishReply();
            return;
          }
          advice.hidden=false;
          let index=0;
          const writeNext=()=>{
            if (index>=adviceText.length) {
              finishReply();
              return;
            }
            const character=adviceText[index++];
            advice.textContent+=character;
            if (chatScroll && index%9===0) chatScroll.scrollTop=chatScroll.scrollHeight;
            schedule(writeNext,'.,;:!?'.includes(character)?48:9);
          };
          writeNext();
        };
        const typeNext=()=>{
          while(nodeIndex<textNodes.length && characterIndex>=textNodes[nodeIndex].value.length) { nodeIndex++; characterIndex=0; }
          if(nodeIndex>=textNodes.length) {
            typeAdvice();
            return;
          }
          const current=textNodes[nodeIndex];
          const character=current.value[characterIndex++];
          current.node.nodeValue+=character;
          if(chatScroll && characterIndex%9===0) chatScroll.scrollTop=chatScroll.scrollHeight;
          const pause='.,;:!?'.includes(character)?48:9;
          schedule(typeNext,pause);
        };
        typeNext();
      },850);
    }

    function showAddRecipe() {
      switchView('add');
      if (addNameStep) addNameStep.hidden = false;
      if (addDetailsStep) addDetailsStep.hidden = true;
      if (addNext) { addNext.textContent = '→'; addNext.classList.remove('is-save'); }
      if (addNameInput) {
        const medicine = 'Ibuprofeno 400 mg';
        addNameInput.value = '';
        [...medicine].forEach((letter, index) => schedule(() => {
          if (addNameInput) addNameInput.value += letter;
        }, 100 + index * 72));
      }
    }

    const calendarGrid = $('#sim-view-calendar .calendar-grid');
    let calendarExpanded = false;
    const progressPeriodButtons = $$('.progress-period [data-period]', $('#sim-view-stats'));
    const progressValues = {
      week:  {taken:12, missed:4, delayed:1, notified:5, total:22, adherence:55, target:80, note:'Faltan 6 dosis a tiempo para alcanzar la meta clínica del 80%.'},
      month: {taken:47, missed:18, delayed:1, notified:20, total:86, adherence:55, target:80, note:'Faltan 22 dosis a tiempo para alcanzar la meta clínica del 80%.'},
      year:  {taken:438, missed:122, delayed:16, notified:64, total:640, adherence:68, target:80, note:'Faltan 77 dosis a tiempo para alcanzar la meta clínica del 80%.'},
      all:   {taken:1248, missed:308, delayed:42, notified:186, total:1784, adherence:70, target:80, note:'Faltan 179 dosis a tiempo para alcanzar la meta clínica del 80%.'}
    };

    function setProgressPeriod(period) {
      const data = progressValues[period] || progressValues.month;
      progressPeriodButtons.forEach(button => button.classList.toggle('active', button.dataset.period === period));
      const ringValue = $('#sim-view-stats .progress-ring-inner strong');
      const totalValue = $('#sim-view-stats .progress-big-number');
      const note = $('#sim-view-stats .progress-stats p');
      const metricNumbers = $$('.progress-metric strong', $('#sim-view-stats'));
      const metricLabels = $$('.progress-metric small', $('#sim-view-stats'));
      const ring = $('#sim-view-stats .progress-ring');
      if (ringValue) ringValue.textContent = `${data.adherence}%`;
      if (totalValue) totalValue.innerHTML = `${data.taken} <small>/ ${data.total} dosis</small>`;
      if (note) note.textContent = data.note;
      [data.taken,data.missed,data.delayed,data.notified].forEach((value,index) => { if (metricNumbers[index]) metricNumbers[index].textContent = value; });
      if (metricLabels[0]) metricLabels[0].textContent = `${data.adherence}% a tiempo`;
      if (metricLabels[1]) metricLabels[1].textContent = `${Math.round(data.missed/data.total*100)}% sin tomar`;
      if (metricLabels[2]) metricLabels[2].textContent = data.delayed ? 'Pospuestas' : 'Sin retrasos';
      if (metricLabels[3]) metricLabels[3].textContent = data.notified ? 'Por confirmar' : 'Al día';
      if (ring) {
        const takenAngle=data.adherence, missedAngle=Math.round(data.missed/data.total*100), delayedAngle=Math.max(3,Math.round(data.delayed/data.total*100));
        ring.style.background=`conic-gradient(#12b886 0 ${takenAngle}%, #ffb000 ${takenAngle}% ${takenAngle+delayedAngle}%, #ff453e ${takenAngle+delayedAngle}% ${Math.min(100,takenAngle+delayedAngle+missedAngle)}%, #d8e0ed ${Math.min(100,takenAngle+delayedAngle+missedAngle)}% 100%)`;
      }
    }

    function calendarYearAndMonth() {
      const absoluteMonth=9+calendarMonthIndex;
      return {year:2026+Math.floor(absoluteMonth/12),month:((absoluteMonth%12)+12)%12};
    }

    const calendarDailyProfiles = [
      { completed: 2, states: ['taken', 'missed', 'notified', 'pending'] },
      { completed: 4, states: ['taken', 'taken', 'missed', 'notified'] },
      { completed: 7, states: ['taken', 'taken', 'notified', 'taken'] },
      { completed: 5, states: ['missed', 'taken', 'taken', 'pending'] },
      { completed: 8, states: ['taken', 'taken', 'taken', 'notified'] }
    ];

    function updateCalendarTreatments() {
      const profile = calendarDailyProfiles[calendarDay % calendarDailyProfiles.length];
      const stateDetails = {
        taken: { itemClass: 'complete', stateClass: 'state-done', icon: '✓', timeClass: '', label: 'Tomada' },
        missed: { itemClass: '', stateClass: 'state-missed', icon: '×', timeClass: 'time-red', label: 'Omitida' },
        notified: { itemClass: '', stateClass: 'state-alert', icon: '♟', timeClass: 'time-amber', label: 'Notificada' },
        pending: { itemClass: '', stateClass: 'state-pending', icon: '•', timeClass: 'time-pending', label: 'Pendiente' }
      };
      const items = $$('.calendar-med-item', $('#sim-view-calendar'));
      items.forEach((item, index) => {
        const detail = stateDetails[profile.states[index] || 'pending'];
        const state = $('.calendar-dose-state', item);
        const time = $('.med-time', item);
        item.classList.remove('complete', 'is-updating');
        if (detail.itemClass) item.classList.add(detail.itemClass);
        if (state) {
          state.className = `calendar-dose-state ${detail.stateClass}`;
          state.textContent = detail.icon;
          state.setAttribute('aria-label', detail.label);
        }
        if (time) {
          time.classList.remove('time-red', 'time-amber', 'time-pending');
          if (detail.timeClass) time.classList.add(detail.timeClass);
        }
        // Restart a small state-change animation without moving the list.
        requestAnimationFrame(() => item.classList.add('is-updating'));
      });
      const summary = $('#sim-view-calendar .calendar-summary-header span');
      const progressFill = $('#sim-view-calendar .calendar-progress-fill');
      if (summary) summary.textContent = `${profile.completed} de 9 dosis completadas`;
      if (progressFill) progressFill.style.width = `${Math.round((profile.completed / 9) * 100)}%`;
    }

    function renderCalendarMonth() {
      if (!calendarGrid) return;
      const {year,month}=calendarYearAndMonth();
      const anchor=new Date(year,month,calendarDay-4);
      const cells=[];
      for(let index=0;index<35;index++) {
        const date=new Date(anchor.getFullYear(),anchor.getMonth(),anchor.getDate()+index);
        const day=date.getDate();
        const outside=date.getMonth()!==month;
        const tone=day%7===0?'day-done':day%6===0?'day-missed':day%4===0?'day-late':'';
        cells.push(`<button type="button" class="calendar-day ${tone}${outside?' muted':''}" data-calendar-date="${day}" data-calendar-month="${date.getMonth()}" data-calendar-year="${date.getFullYear()}">${day}</button>`);
      }
      calendarGrid.innerHTML=cells.join('');
      updateCalendarSelection();
    }

    function collapseCalendarWeek() {
      if (!calendarGrid) return;
      const {year,month}=calendarYearAndMonth();
      const anchor=new Date(year,month,calendarDay-4);
      calendarGrid.innerHTML=Array.from({length:7},(_,index)=>{
        const date=new Date(anchor.getFullYear(),anchor.getMonth(),anchor.getDate()+index);
        const day=date.getDate();
        const tone=day%7===0?'day-done':day%6===0?'day-missed':day%4===0?'day-late':'';
        return `<button type="button" class="calendar-day ${tone}" data-calendar-date="${day}" data-calendar-month="${date.getMonth()}" data-calendar-year="${date.getFullYear()}">${day}</button>`;
      }).join('');
      updateCalendarSelection();
    }

    function expandCalendar() {
      if (!calendarGrid) return;
      calendarExpanded=false;
      $('#sim-view-calendar .calendar-month-card')?.classList.remove('expanded');
      collapseCalendarWeek();
    }

    function updateCalendarSelection() {
      const monthNames=['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
      const {year,month}=calendarYearAndMonth();
      const monthLabel=$('#sim-view-calendar .calendar-month');
      if (monthLabel) monthLabel.textContent=`${monthNames[month]} de ${year}`;
      $$('.calendar-day[data-calendar-date]', $('#sim-view-calendar')).forEach(day=>day.classList.toggle('selected',Number(day.dataset.calendarDate)===calendarDay && Number(day.dataset.calendarMonth)===month && Number(day.dataset.calendarYear)===year));
      updateCalendarTreatments();
    }

    function advanceCalendar() {
      const {year,month}=calendarYearAndMonth();
      const daysInMonth=new Date(year,month+1,0).getDate();
      if(calendarDay>=daysInMonth) { calendarDay=1; calendarMonthIndex++; }
      else calendarDay++;
      const visible=$$('.calendar-day[data-calendar-date]',calendarGrid).some(day=>Number(day.dataset.calendarDate)===calendarDay && Number(day.dataset.calendarMonth)===calendarYearAndMonth().month && Number(day.dataset.calendarYear)===calendarYearAndMonth().year);
      if(!visible) collapseCalendarWeek(); else updateCalendarSelection();
    }

    progressPeriodButtons.forEach(button => button.addEventListener('click',() => setProgressPeriod(button.dataset.period)));
    $('#sim-view-calendar .calendar-grid')?.addEventListener('click', event => {
      const day=event.target.closest('[data-calendar-date]');
      if (!day) return;
      const selectedMonth=Number(day.dataset.calendarMonth);
      const selectedYear=Number(day.dataset.calendarYear);
      calendarMonthIndex=(selectedYear-2026)*12+selectedMonth-9;
      calendarDay=Number(day.dataset.calendarDate);
      updateCalendarSelection();
    });
    $$('#sim-view-calendar .calendar-arrow').forEach((button,index)=>button.addEventListener('click',()=>{
      const {year,month}=calendarYearAndMonth();
      const nextDate=new Date(year,month,calendarDay+(index===0?-7:7));
      calendarMonthIndex=(nextDate.getFullYear()-2026)*12+nextDate.getMonth()-9;
      calendarDay=nextDate.getDate();
      calendarExpanded=false;
      $('#sim-view-calendar .calendar-month-card')?.classList.remove('expanded');
      collapseCalendarWeek();
    }));

    function saveTourRecipe() {
      switchView('plan');
      if (doseNew) doseNew.classList.add('revealed');
      if (doseCount) doseCount.textContent = '4 tomas';
      if (scrollArea) scrollArea.scrollTo({ top: scrollArea.scrollHeight, behavior: 'smooth' });
      if (fabAdd) fabAdd.classList.add('pressed');
      schedule(() => fabAdd?.classList.remove('pressed'), 500);
    }

    function runSimulationCycle() {
      clearAllTimeouts();
      switchView('plan');
      if (scrollArea) scrollArea.scrollTo({ top: 0, behavior: 'auto' });
      if (progressScroll) progressScroll.scrollTo({ top:0, behavior:'auto' });
      if (chatScroll) chatScroll.scrollTo({ top:0, behavior:'auto' });
      if (alarmBanner) alarmBanner.classList.remove('active');
      if (bottomSheet) bottomSheet.classList.remove('active');
      if (sheetBackdrop) sheetBackdrop.classList.remove('active');
      if (doseNew) doseNew.classList.remove('revealed');
      if (doseCount) doseCount.textContent = '3 tomas';
      if (node1) {
        node1.className = 'sim-dose-node node-missed';
        node1.innerHTML = '<span>×</span>';
      }
      if (node2) {
        node2.className = 'sim-dose-node node-pending';
        node2.innerHTML = '';
      }
      if (pill1) { pill1.textContent = 'Pendiente'; pill1.className = 'sim-status-pill pill-pending'; }
      if (metricPending) metricPending.textContent = '2';
      if (metricTaken) metricTaken.textContent = '1';
      if (metricAdherence) metricAdherence.textContent = '67%';
      setProgressPeriod('month');
      $('#sim-view-calendar .calendar-month-card')?.classList.remove('expanded');
      calendarExpanded=false;
      collapseCalendarWeek();

      // Review the upcoming dose and receive a heads-up notification.
      const doseItems = [$('#sim-dose-1'), $('#sim-dose-2'), $('#sim-dose-3')];
      doseItems.forEach((item, index) => schedule(() => {
        item?.classList.add('sim-dose-arrive');
        schedule(() => item?.classList.remove('sim-dose-arrive'), 850);
      }, 350 + index * 450));
      schedule(() => {
        if (node2) {
          node2.className = 'sim-dose-node node-alert';
          node2.innerHTML = '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round" aria-label="Notificación de dosis"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>';
        }
        alarmBanner?.classList.add('active');
      }, 2100);
      schedule(() => {
        alarmBanner?.classList.remove('active');
        if (node2) { node2.className='sim-dose-node node-taken'; node2.innerHTML='<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.2"><polyline points="20 6 9 17 4 12"/></svg>'; }
        if (metricPending) metricPending.textContent='1';
        if (metricTaken) metricTaken.textContent='2';
        if (metricAdherence) metricAdherence.textContent='100%';
      }, 4200);

      // Advance through the calendar and inspect the adherence report.
      schedule(() => {
        expandCalendar(); switchView('calendar');
        const calendarScroll=$('#sim-view-calendar .sim-calendar-screen');
        if (calendarScroll) calendarScroll.scrollTo({top:0,behavior:'auto'});
        [1,2,3,4,5].forEach(step=>schedule(advanceCalendar,650+step*760));
      }, 5200);
      schedule(() => {
        switchView('stats'); setProgressPeriod('month');
        if (progressScroll) {
          schedule(() => progressScroll.scrollTo({top:20,behavior:'smooth'}),700);
          schedule(() => progressScroll.scrollTo({top:0,behavior:'smooth'}),2900);
        }
        schedule(() => setProgressPeriod('week'),900);
        schedule(() => setProgressPeriod('month'),1950);
        schedule(() => setProgressPeriod('year'),3000);
        schedule(() => setProgressPeriod('all'),4050);
      }, 10100);

      // Ask Midi about active medicine, then enter the add-prescription flow.
      schedule(() => {
        switchView('assistant');
        if (chatScroll) chatScroll.scrollTo({top:0,behavior:'auto'});
        animateAssistantReply();
      }, 15100);
      schedule(showAddRecipe, 20200);
      schedule(() => {
        if (addNameStep) addNameStep.hidden=true;
        if (addDetailsStep) addDetailsStep.hidden=false;
        if (addNext) { addNext.textContent='Guardar'; addNext.classList.add('is-save'); }
      }, 22600);
      schedule(saveTourRecipe, 24900);
      // Pause on the newly added dose before smoothly starting the next pass.
      schedule(() => { if (isHeroVisible) runSimulationCycle(); }, 29300);
    }

    fabAdd?.addEventListener('click', () => { clearAllTimeouts(); showAddRecipe(); });
    $('#sim-add-back')?.addEventListener('click', () => { clearAllTimeouts(); runSimulationCycle(); });
    $('#sim-assistant-back')?.addEventListener('click', () => { clearAllTimeouts(); runSimulationCycle(); });
    addNext?.addEventListener('click', () => {
      if (addNameStep && !addNameStep.hidden) {
        addNameStep.hidden=true;
        if (addDetailsStep) addDetailsStep.hidden=false;
        addNext.textContent='Guardar';
        addNext.classList.add('is-save');
      } else {
        clearAllTimeouts();
        saveTourRecipe();
        schedule(() => { if (isHeroVisible) runSimulationCycle(); }, 2500);
      }
    });

    // Permitir interacción opcional al pulsar pestañas del simulador
    const navButtons = [tabPlan, tabCalendar, tabStats];
    navButtons.forEach(btn => {
      if (btn) {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const target = btn.getAttribute('data-target');
          if (target) {
            clearAllTimeouts();
            switchView(target);
            if (target === 'calendar' && islandContent) {
              islandContent.innerHTML = '<span class="island-icon-alarm"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:middle;margin-right:4px;" aria-hidden="true"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg></span><span class="island-text">Calendario mensual</span>';
            } else if (target === 'stats' && islandContent) {
              islandContent.innerHTML = '<span class="island-icon-alarm"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:middle;margin-right:4px;" aria-hidden="true"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg></span><span class="island-text">Progreso y Adherencia</span>';
            } else if (target === 'plan' && islandContent) {
              islandContent.innerHTML = '<span class="island-icon-alarm"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:middle;margin-right:4px;" aria-hidden="true"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg></span><span class="island-text">18:22 · Dosis lista</span>';
            }
            // Reanudar la simulación tras pausa de exploración
            schedule(() => {
              if (isHeroVisible) runSimulationCycle();
            }, 6000);
          }
        });
      }
    });

    // Control de ciclo según visibilidad en pantalla para no saturar recursos en scroll
    let isHeroVisible = true;
    let isLoopRunning = false;

    function startSimulatorLoop() {
      if (isLoopRunning || !isHeroVisible) return;
      isLoopRunning = true;
      runSimulationCycle();
    }

    function stopSimulatorLoop() {
      isLoopRunning = false;
      clearAllTimeouts();
    }

    const heroSectionElem = $('#hero');
    if (heroSectionElem && 'IntersectionObserver' in window) {
      const heroVisObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          isHeroVisible = entry.isIntersecting;
          if (isHeroVisible) {
            startSimulatorLoop();
          } else {
            stopSimulatorLoop();
          }
        });
      }, { threshold: 0.05 });
      heroVisObserver.observe(heroSectionElem);
    } else {
      startSimulatorLoop();
    }
  }

  initPhoneHeroSimulator();
});
