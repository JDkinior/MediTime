/**
 * MedDue · Animaciones de partículas, demostración y navegación.
 */
(() => {
  'use strict';

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const HEADER_SCROLL_OFFSET = 72;
  const $ = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => Array.from(ctx.querySelectorAll(sel));

  // --- 1. THEME MANAGER ---
  const MOON_SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>';
  const SUN_SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>';

  function initTheme() {
    const btn = $('#theme-toggle');
    const apply = (theme, persist) => {
      document.documentElement.setAttribute('data-theme', theme);
      if (btn) {
        btn.innerHTML = theme === 'dark' ? SUN_SVG : MOON_SVG;
        btn.setAttribute('aria-label', theme === 'dark' ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro');
      }
      if (persist) localStorage.setItem('meditime_theme', theme);
      document.dispatchEvent(new CustomEvent('meddue-theme-change', { detail: { theme } }));
    };

    const current = document.documentElement.getAttribute('data-theme') || 'light';
    apply(current, false);

    if (btn) {
      btn.addEventListener('click', () => {
        const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        apply(next, true);
      });
    }
  }

  // --- 2. HEADER & MOBILE NAV ---
  function initNavigation(getLenis) {
    const header = $('.header');
    const menuBtn = $('#menu-toggle');
    const mobileNav = $('#mobile-nav');

    const updateHeader = () => {
      if (header) header.classList.toggle('scrolled', window.scrollY > 10);
    };
    window.addEventListener('scroll', updateHeader, { passive: true });
    updateHeader();

    if (menuBtn && mobileNav) {
      menuBtn.addEventListener('click', () => {
        const isOpen = mobileNav.classList.toggle('open');
        menuBtn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
      });
    }

    document.addEventListener('click', (e) => {
      const link = e.target.closest('a[href^="#"]');
      if (!link) return;
      const hash = link.getAttribute('href');
      if (!hash || hash === '#') return;
      const target = document.querySelector(hash);
      if (!target) return;

      e.preventDefault();
      if (mobileNav && mobileNav.classList.contains('open')) {
        mobileNav.classList.remove('open');
        if (menuBtn) menuBtn.setAttribute('aria-expanded', 'false');
      }

      const top = hash === '#hero' ? 0 : Math.max(0, target.getBoundingClientRect().top + window.scrollY - HEADER_SCROLL_OFFSET);
      const lenis = getLenis();
      if (lenis) {
        lenis.scrollTo(top);
      } else {
        window.scrollTo({ top, behavior: prefersReducedMotion ? 'auto' : 'smooth' });
      }
    });
  }

  // --- 3. LENIS SMOOTH SCROLL ---
  function initSmoothScroll() {
    if (prefersReducedMotion || typeof window.Lenis === 'undefined') return null;

    const lenis = new window.Lenis({
      lerp: 0.1,
      smoothWheel: true,
      syncTouch: false
    });

    if (typeof window.gsap !== 'undefined' && typeof window.ScrollTrigger !== 'undefined') {
      lenis.on('scroll', window.ScrollTrigger.update);
      window.gsap.ticker.add((time) => lenis.raf(time * 1000));
      window.gsap.ticker.lagSmoothing(0);
    } else {
      const raf = (t) => {
        lenis.raf(t);
        requestAnimationFrame(raf);
      };
      requestAnimationFrame(raf);
    }

    return lenis;
  }

  function createArchitectureModels(count, random) {
    const rectangle = (x, y, halfWidth, halfHeight, z = 0) => [
      [x - halfWidth, y + halfHeight, z], [x + halfWidth, y + halfHeight, z],
      [x + halfWidth, y - halfHeight, z], [x - halfWidth, y - halfHeight, z],
      [x - halfWidth, y + halfHeight, z]
    ];
    const circle = (radius, offset, horizontal = false) => Array.from({ length: 49 }, (_, i) => {
      const angle = i * Math.PI / 24;
      const x = Math.cos(angle) * radius;
      const v = Math.sin(angle) * radius;
      return horizontal ? [x, offset, v] : [x, v, offset];
    });

    const particlesOn = (paths) => {
      const segments = [];
      let totalLength = 0;
      for (const line of paths) {
        for (let i = 1; i < line.length; i++) {
          const from = line[i - 1];
          const to = line[i];
          const length = Math.hypot(to[0] - from[0], to[1] - from[1], to[2] - from[2]);
          if (length === 0) continue;
          totalLength += length;
          segments.push({ from, to, length, end: totalLength });
        }
      }

      const points = new Float32Array(count * 3);
      let segment = 0;
      for (let i = 0; i < count; i++) {
        const distance = (i + random()) * totalLength / count;
        while (distance > segments[segment].end) segment++;
        const { from, to, length, end } = segments[segment];
        const mix = 1 - (end - distance) / length;
        for (let axis = 0; axis < 3; axis++) {
          points[i * 3 + axis] = from[axis] + (to[axis] - from[axis]) * mix + (random() - 0.5) * 0.07;
        }
      }
      return points;
    };

    const processor = [
      rectangle(0, 0, 1.04, 1.04, -0.3), rectangle(0, 0, 1.04, 1.04, 0.27),
      rectangle(0, 0, 0.74, 0.74, 0.3), rectangle(0, 0, 0.34, 0.34, 0.38)
    ];
    for (const x of [-1.04, 1.04]) {
      for (const y of [-1.04, 1.04]) processor.push([[x, y, -0.3], [x, y, 0.27]]);
    }
    for (const side of [-1, 1]) {
      for (const pin of [-0.68, -0.34, 0, 0.34, 0.68]) {
        processor.push(
          [[pin, side * 1.04, 0.22], [pin, side * 1.34, 0.22], [pin, side * 1.58, -0.05]],
          [[side * 1.04, pin, 0.22], [side * 1.34, pin, 0.22], [side * 1.58, pin, -0.05]]
        );
      }
    }

    const decisionFlow = [
      rectangle(-1.34, 0, 0.44, 0.40, 0.25),
      rectangle(-0.10, 0, 0.47, 0.51, 0.25),
      rectangle(1.31, 0.78, 0.42, 0.32, 0.25),
      rectangle(1.31, -0.78, 0.42, 0.32, 0.25),
      rectangle(-1.34, 0, 0.44, 0.40, -0.19),
      rectangle(-0.10, 0, 0.47, 0.51, -0.19),
      rectangle(1.31, 0.78, 0.42, 0.32, -0.19),
      rectangle(1.31, -0.78, 0.42, 0.32, -0.19),
      [[-0.90, 0, 0.25], [-0.57, 0, 0.25]],
      [[0.37, 0, 0.25], [0.61, 0, 0.25], [0.61, 0.78, 0.25], [0.89, 0.78, 0.25]],
      [[0.61, 0, 0.25], [0.61, -0.78, 0.25], [0.89, -0.78, 0.25]],
      [[-1.55, 0, 0.27], [-1.13, 0, 0.27]],
      [[-0.32, 0.12, 0.27], [0.12, 0.12, 0.27]],
      [[-0.32, -0.12, 0.27], [0.12, -0.12, 0.27]],
      [[1.14, 0.78, 0.27], [1.48, 0.78, 0.27]],
      [[1.14, -0.78, 0.27], [1.48, -0.78, 0.27]]
    ];

    const alarmClock = [
      circle(1.49, -0.24), circle(1.49, 0.22), circle(1.31, 0.25),
      [[0, 0, 0.34], [0.63, 0.42, 0.34]],
      [[0, 0, 0.34], [-0.28, 0.84, 0.34]],
      [[-0.25, 1.47, 0.04], [-0.25, 1.64, 0.04], [0.25, 1.64, 0.04], [0.25, 1.47, 0.04]]
    ];
    for (let i = 0; i < 12; i++) {
      const angle = i * Math.PI / 6;
      const x = Math.cos(angle);
      const y = Math.sin(angle);
      const inner = i % 3 === 0 ? 1.01 : 1.11;
      alarmClock.push([[x * inner, y * inner, 0.27], [x * 1.22, y * 1.22, 0.27]]);
    }

    const databaseRings = [-1.14, -0.47, 0.22, 0.89, 1.18].map(y => circle(1.14, y, true));
    for (const side of [-1, 1]) {
      databaseRings.push([[side * 1.14, -1.14, 0], [side * 1.14, 1.18, 0]]);
    }
    for (const y of [-0.80, -0.10, 0.58]) {
      databaseRings.push([[0.61, y, 0.96], [0.85, y, 0.76]]);
    }
    // Tilt the cylinder so its circular faces remain visible even when facing forward.
    const localDatabase = databaseRings.map(line => line.map(([x, y, z]) => [
      x, y * 0.93 - z * 0.37, y * 0.37 + z * 0.93
    ]));

    const reportDocument = [
      [[-0.99, -1.35, 0.26], [0.99, -1.35, 0.26], [0.99, 0.73, 0.26],
        [0.44, 1.32, 0.26], [-0.99, 1.32, 0.26], [-0.99, -1.35, 0.26]],
      [[0.44, 1.32, 0.26], [0.44, 0.73, 0.29], [0.99, 0.73, 0.26]],
      [[-0.74, -1.56, -0.28], [1.20, -1.56, -0.28], [1.20, 0.48, -0.28], [0.78, 0.91, -0.28]],
      [[-0.67, 0.96, 0.28], [0.13, 0.96, 0.28]],
      [[-0.67, 0.45, 0.28], [0.67, 0.45, 0.28]],
      [[-0.67, 0.14, 0.28], [0.56, 0.14, 0.28]],
      [[-0.67, -0.17, 0.28], [0.67, -0.17, 0.28]],
      rectangle(0.40, -0.84, 0.27, 0.23, 0.3),
      [[0.22, -0.83, 0.32], [0.36, -0.96, 0.32], [0.58, -0.72, 0.32]]
    ];

    return {
      processor: particlesOn(processor),
      decisionFlow: particlesOn(decisionFlow),
      alarmClock: particlesOn(alarmClock),
      localDatabase: particlesOn(localDatabase),
      reportDocument: particlesOn(reportDocument)
    };
  }

  // --- 4. DETERMINISTIC 1,100-PARTICLE 3D MORPHING ENGINE (PORTFOLIO STYLE) ---
  function initThreeScene() {
    const stage = $('#meddue-3d-stage');
    const canvas = $('#meddue-3d-canvas');
    if (!stage || !canvas || typeof window.THREE === 'undefined') {
      if (stage) stage.style.display = 'none';
      return null;
    }

    const THREE = window.THREE;
    let renderer;
    try {
      renderer = new THREE.WebGLRenderer({
        canvas,
        alpha: true,
        antialias: true,
        powerPreference: 'high-performance'
      });
    } catch {
      stage.style.display = 'none';
      return null;
    }

    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setClearColor(0x000000, 0);

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(44, window.innerWidth / window.innerHeight, 0.1, 100);
    camera.position.set(0, 0, 7.6);
    camera.updateMatrixWorld();

    const isLowPower =
      window.innerWidth < 768 ||
      (typeof navigator !== 'undefined' && navigator.hardwareConcurrency && navigator.hardwareConcurrency <= 4);

    const COUNT = isLowPower ? 650 : 1100;
    const isArchitecturePage = document.body.classList.contains('architecture-page');

    const masterGroup = new THREE.Group();
    const isSmall = window.innerWidth < 960;
    masterGroup.position.set(isSmall ? 0 : 1.92, isSmall ? 0.45 : 0.12, 0);
    scene.add(masterGroup);

    function createShapes(n) {
      const shapes = {
        phone: new Float32Array(n * 3),
        phoneCloud: new Float32Array(n * 2),
        pill: new Float32Array(n * 3),
        neural: new Float32Array(n * 3),
        heart: new Float32Array(n * 3),
        chart: new Float32Array(n * 3),
        globe: new Float32Array(n * 3),
        paw: new Float32Array(n * 3),
        waves: new Float32Array(n * 3),
        scan: new Float32Array(n * 3),
        questions: new Float32Array(n * 3),
        birthY: new Float32Array(n),
        driftVec: new Float32Array(n * 3)
      };

      let seed = 2026;
      const rand = () => {
        seed = (seed * 16807) % 2147483647;
        return (seed - 1) / 2147483646;
      };

      // 1) Precision double-contour rounded-rectangle phone wireframe (un-rotated in local XY)
      const sampleRoundedRect = (t, hw, hh, rad) => {
        const sw = 2 * (hw - rad);
        const sh = 2 * (hh - rad);
        const arc = 0.5 * Math.PI * rad;
        const perim = 2 * sw + 2 * sh + 4 * arc;
        let s = (((t % 1) + 1) % 1) * perim;

        if (s < sw) return [-hw + rad + s, hh];
        s -= sw;
        if (s < arc) {
          const a = Math.PI * 0.5 - (s / arc) * (Math.PI * 0.5);
          return [hw - rad + Math.cos(a) * rad, hh - rad + Math.sin(a) * rad];
        }
        s -= arc;
        if (s < sh) return [hw, hh - rad - s];
        s -= sh;
        if (s < arc) {
          const a = -(s / arc) * (Math.PI * 0.5);
          return [hw - rad + Math.cos(a) * rad, -hh + rad + Math.sin(a) * rad];
        }
        s -= arc;
        if (s < sw) return [hw - rad - s, -hh];
        s -= sw;
        if (s < arc) {
          const a = -Math.PI * 0.5 - (s / arc) * (Math.PI * 0.5);
          return [-hw + rad + Math.cos(a) * rad, -hh + rad + Math.sin(a) * rad];
        }
        s -= arc;
        if (s < sh) return [-hw, -hh + rad + s];
        s -= sh;
        const a = Math.PI - (s / arc) * (Math.PI * 0.5);
        return [-hw + rad + Math.cos(a) * rad, hh - rad + Math.sin(a) * rad];
      };

      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        const part = i / n;
        let px = 0;
        let py = 0;
        let pz = 0;

        if (part < 0.35) {
          // Outer metallic chassis contour with true 3D thickness (front bezel & rear casing)
          const u = i / Math.floor(n * 0.35);
          const [rx, ry] = sampleRoundedRect(u, 0.905, 1.775, 0.245);
          px = rx + (rand() - 0.5) * 0.028;
          py = ry + (rand() - 0.5) * 0.028;
          pz = (i % 2 === 0 ? 0.06 : -0.14) + (rand() - 0.5) * 0.02;
        } else if (part < 0.60) {
          // Inner screen bezel frame (25%)
          const u = (i - Math.floor(n * 0.35)) / Math.max(1, Math.floor(n * 0.25));
          const [rx, ry] = sampleRoundedRect(u, 0.815, 1.685, 0.198);
          px = rx + (rand() - 0.5) * 0.03;
          py = ry + (rand() - 0.5) * 0.03;
          pz = (rand() - 0.5) * 0.04;
        } else {
          // Structured digital screen matrix / UI rows (40%)
          const row = Math.floor(rand() * 14);
          px = (rand() - 0.5) * 1.40;
          py = -1.44 + (row / 13) * 2.88 + (rand() - 0.5) * 0.065;
          pz = (rand() - 0.5) * 0.04;
        }

        shapes.phone[i3] = px;
        shapes.phone[i3 + 1] = py;
        shapes.phone[i3 + 2] = pz;

        const normY = Math.max(0, Math.min(1, (py + 1.775) / 3.55));
        shapes.birthY[i] = Math.max(0.005, Math.min(0.995, normY + (rand() - 0.5) * 0.05));

        const sideSign = px >= 0 ? 1 : -1;
        shapes.driftVec[i3] = sideSign * (0.25 + rand() * 0.40);
        shapes.driftVec[i3 + 1] = (rand() - 0.5) * 0.50;
        shapes.driftVec[i3 + 2] = (rand() - 0.5) * 0.70;
      }

      // 2) Medical Pill / Capsule + Orbital Alarm Ring (Pillar 01)
      const capsuleCount = Math.floor(n * 0.76);
      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        if (i < capsuleCount) {
          const theta = rand() * Math.PI * 2;
          const r = 0.72 + (rand() - 0.5) * 0.07;
          const u = rand();
          let lx = 0;
          let ly = 0;
          let lz = 0;
          if (u < 0.28) {
            // Top hemisphere
            const phi = Math.acos(rand());
            lx = r * Math.sin(phi) * Math.cos(theta);
            ly = 0.65 + r * Math.cos(phi);
            lz = r * Math.sin(phi) * Math.sin(theta);
          } else if (u < 0.56) {
            // Bottom hemisphere
            const phi = Math.acos(-rand());
            lx = r * Math.sin(phi) * Math.cos(theta);
            ly = -0.65 + r * Math.cos(phi);
            lz = r * Math.sin(phi) * Math.sin(theta);
          } else {
            // Cylinder body
            lx = r * Math.cos(theta);
            ly = (rand() - 0.5) * 1.3;
            lz = r * Math.sin(theta);
          }
          // Tilt capsule 22deg for dynamic silhouette
          const tilt = -0.38;
          shapes.pill[i3] = lx * Math.cos(tilt) - ly * Math.sin(tilt);
          shapes.pill[i3 + 1] = lx * Math.sin(tilt) + ly * Math.cos(tilt);
          shapes.pill[i3 + 2] = lz;
        } else {
          // Orbital alarm ring around pill
          const a = ((i - capsuleCount) / (n - capsuleCount)) * Math.PI * 2;
          const R = 1.65 + (rand() - 0.5) * 0.1;
          shapes.pill[i3] = Math.cos(a) * R;
          shapes.pill[i3 + 1] = Math.sin(a) * 0.48 + (rand() - 0.5) * 0.08;
          shapes.pill[i3 + 2] = Math.sin(a) * R;
        }
      }

      // 4) 3D Volumetric Care Heart + Halo (Pillar 03: Cuidador & Animales)
      const heartCoreCount = Math.floor(n * 0.8);
      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        if (i < heartCoreCount) {
          const t = rand() * Math.PI * 2;
          const shell = 0.72 + 0.32 * Math.sqrt(rand());
          const hx = 16 * Math.pow(Math.sin(t), 3);
          const hy = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t);
          shapes.heart[i3] = (hx / 11.5) * shell;
          shapes.heart[i3 + 1] = ((hy + 2.2) / 11.5) * shell;
          shapes.heart[i3 + 2] = (rand() - 0.5) * 0.78 * (1.15 - Math.abs(hx) / 18);
        } else {
          const a = ((i - heartCoreCount) / (n - heartCoreCount)) * Math.PI * 2;
          const R = 1.95 + (rand() - 0.5) * 0.08;
          shapes.heart[i3] = Math.cos(a) * R;
          shapes.heart[i3 + 1] = Math.sin(a) * 0.42;
          shapes.heart[i3 + 2] = Math.sin(a) * R;
        }
      }

      // 5) 3D Adherence Bar Chart + Progress Arc (Pillar 04: Reportes PDF & Progreso)
      const barsCount = Math.floor(n * 0.72);
      const barHeights = [1.05, 1.55, 2.1, 2.75];
      const barXs = [-1.15, -0.38, 0.38, 1.15];
      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        if (i < barsCount) {
          const b = i % 4;
          const h = barHeights[b];
          shapes.chart[i3] = barXs[b] + (rand() - 0.5) * 0.42;
          shapes.chart[i3 + 1] = -1.25 + rand() * h;
          shapes.chart[i3 + 2] = (rand() - 0.5) * 0.42;
        } else {
          // Ascending progress arc above bars
          const frac = (i - barsCount) / (n - barsCount);
          const a = Math.PI * 0.1 + frac * Math.PI * 0.8;
          const R = 1.82 + (rand() - 0.5) * 0.08;
          shapes.chart[i3] = -Math.cos(a) * R;
          shapes.chart[i3 + 1] = -0.15 + Math.sin(a) * R * 0.85;
          shapes.chart[i3 + 2] = (rand() - 0.5) * 0.25;
        }
      }

      // 8) 3D Connected Care Globe + Orbital Ring (#about)
      const globeSphere = Math.floor(n * 0.78);
      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        if (i < globeSphere) {
          const lat = ((i % 9) - 4) * 0.32 + (rand() - 0.5) * 0.05;
          const lon = rand() * Math.PI * 2;
          const r = 1.35 + (rand() - 0.5) * 0.06;
          shapes.globe[i3] = r * Math.cos(lat) * Math.cos(lon);
          shapes.globe[i3 + 1] = r * Math.sin(lat);
          shapes.globe[i3 + 2] = r * Math.cos(lat) * Math.sin(lon);
        } else {
          const a = ((i - globeSphere) / (n - globeSphere)) * Math.PI * 2;
          const R = 1.82 + (rand() - 0.5) * 0.08;
          const tilt = 0.42;
          const gx = Math.cos(a) * R;
          const gy = Math.sin(a) * 0.45;
          shapes.globe[i3] = gx * Math.cos(tilt) - gy * Math.sin(tilt);
          shapes.globe[i3 + 1] = gx * Math.sin(tilt) + gy * Math.cos(tilt);
          shapes.globe[i3 + 2] = Math.sin(a) * R;
        }
      }

      // 9) 3D Veterinary Paw Emblem + Halo (modos.html: Modo Animales)
      const pawMain = Math.floor(n * 0.42);
      const pawToes = Math.floor(n * 0.82);
      const toeCenters = [
        [-1.08, 0.52],
        [-0.40, 1.02],
        [0.40, 1.02],
        [1.08, 0.52]
      ];
      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        if (i < pawMain) {
          // Sculpted central metacarpal pad
          const a = rand() * Math.PI * 2;
          const rad = Math.sqrt(rand());
          const px = Math.cos(a) * 0.88 * rad;
          const py = Math.sin(a) * 0.68 * rad - 0.42 + Math.cos(a * 2) * 0.12 * rad;
          shapes.paw[i3] = px;
          shapes.paw[i3 + 1] = py;
          shapes.paw[i3 + 2] = (rand() - 0.5) * 0.34;
        } else if (i < pawToes) {
          const toe = toeCenters[(i - pawMain) % 4];
          const a = rand() * Math.PI * 2;
          const rad = Math.sqrt(rand());
          shapes.paw[i3] = toe[0] + Math.cos(a) * 0.28 * rad;
          shapes.paw[i3 + 1] = toe[1] + Math.sin(a) * 0.38 * rad;
          shapes.paw[i3 + 2] = (rand() - 0.5) * 0.28;
        } else {
          const a = ((i - pawToes) / (n - pawToes)) * Math.PI * 2;
          const R = 1.88 + (rand() - 0.5) * 0.07;
          shapes.paw[i3] = Math.cos(a) * R;
          shapes.paw[i3 + 1] = Math.sin(a) * 0.42 - 0.05;
          shapes.paw[i3 + 2] = Math.sin(a) * R;
        }
      }

      const question = new THREE.CurvePath();
      const questionSegments = [
        [[-0.64, 0.42], [-0.64, 1.17], [0.76, 1.19], [0.69, 0.48]],
        [[0.69, 0.48], [0.65, 0.08], [-0.08, 0.06], [-0.08, -0.34]]
      ];
      for (const segment of questionSegments) {
        question.add(new THREE.CubicBezierCurve(...segment.map(([x, y]) => new THREE.Vector2(x, y))));
      }

      const waveRows = 13;
      const waveColumns = Math.ceil(n / waveRows);
      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        const row = i % waveRows;
        const col = Math.floor(i / waveRows);
        shapes.waves[i3] = -1 + 2 * (col + 0.25 + rand() * 0.5) / waveColumns;
        shapes.waves[i3 + 1] = -0.78 + 1.56 * row / (waveRows - 1) + (rand() - 0.5) * 0.02;
        shapes.waves[i3 + 2] = rand();

        const isQr = i % 5 < 3;
        const u = rand();
        if (isQr) {
          const [x, y] = sampleRoundedRect(u, 1, 1, 0.065);
          const sweep = i % 8 === 0;
          shapes.scan[i3] = sweep ? u * 2 - 1 : x;
          shapes.scan[i3 + 1] = sweep ? (rand() - 0.5) * 0.085 : y;
        } else {
          const roundedEnd = i % 8 < 3;
          const angle = u * Math.PI * 2;
          shapes.scan[i3] = roundedEnd ? Math.cos(angle) : u * 2 - 1;
          shapes.scan[i3 + 1] = roundedEnd ? Math.sin(angle) : (i % 2 === 0 ? 1 : -1);
        }
        shapes.scan[i3 + 2] = rand();

        const onDot = rand() < 0.17;
        const angle = rand() * Math.PI * 2;
        const radius = Math.sqrt(rand()) * (onDot ? 0.115 : 0.087);
        const point = onDot ? new THREE.Vector2(-0.08, -0.70) : question.getPointAt(rand());
        const direction = i % 3 === 1 ? -1 : 1;
        shapes.questions[i3] = (point.x + Math.cos(angle) * radius) * direction;
        shapes.questions[i3 + 1] = (point.y + Math.sin(angle) * radius) * direction;
        shapes.questions[i3 + 2] = (rand() - 0.5) * (onDot ? 0.28 : 0.40);
      }

      // The demo assembles from loose particles, using the hero's height order in reverse.
      for (let i = 0; i < n; i++) {
        const angle = rand() * Math.PI * 2;
        const radius = Math.sqrt(rand());
        shapes.phoneCloud[i * 2] = Math.cos(angle) * radius * 1.65;
        shapes.phoneCloud[i * 2 + 1] = Math.sin(angle) * radius * 2.15;
      }

      // Four connected layers for the Midi IA chapter.
      const layers = [-1.42, -0.48, 0.48, 1.42];
      for (let i = 0; i < n; i++) {
        const i3 = i * 3;
        const layer = i % layers.length;
        const node = Math.floor(i / layers.length) % 6;
        const angle = node * Math.PI / 3;
        const y = Math.sin(angle) * 1.02;
        const z = Math.cos(angle) * 1.02;

        if (rand() < 0.62) {
          shapes.neural[i3] = layers[layer] + (rand() - 0.5) * 0.20;
          shapes.neural[i3 + 1] = y + (rand() - 0.5) * 0.20;
          shapes.neural[i3 + 2] = z + (rand() - 0.5) * 0.20;
        } else {
          const next = (layer + 1) % layers.length;
          const mix = rand();
          shapes.neural[i3] = layers[layer] * (1 - mix) + layers[next] * mix;
          shapes.neural[i3 + 1] = y * (1 - mix) + Math.sin(angle + 1.05) * 1.02 * mix;
          shapes.neural[i3 + 2] = z * (1 - mix) + Math.cos(angle + 1.05) * 1.02 * mix;
        }
      }

      if (isArchitecturePage) {
        Object.assign(shapes, createArchitectureModels(n, rand));
      }
      return shapes;
    }

    const createCircleTexture = () => {
      const c = document.createElement('canvas');
      c.width = 32;
      c.height = 32;
      const ctx = c.getContext('2d');
      const g = ctx.createRadialGradient(16, 16, 0, 16, 16, 16);
      g.addColorStop(0, 'rgba(255, 255, 255, 1)');
      g.addColorStop(0.38, 'rgba(255, 255, 255, 0.92)');
      g.addColorStop(0.75, 'rgba(255, 255, 255, 0.35)');
      g.addColorStop(1, 'rgba(255, 255, 255, 0)');
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, 32, 32);
      const tex = new THREE.CanvasTexture(c);
      tex.needsUpdate = true;
      return tex;
    };
    const spriteTex = createCircleTexture();

    const shapes = createShapes(COUNT);
    const currentPositions = new Float32Array(shapes.phone);
    const colors = new Float32Array(COUNT * 3);
    const wasBorn = new Uint8Array(COUNT);
    for (let i = 0; i < COUNT; i++) {
      colors[i * 3] = 0.23;
      colors[i * 3 + 1] = 0.51;
      colors[i * 3 + 2] = 0.96;
    }

    const geo = new THREE.BufferGeometry();
    const posAttr = new THREE.BufferAttribute(currentPositions, 3);
    const colorAttr = new THREE.BufferAttribute(colors, 3);
    geo.setAttribute('position', posAttr);
    geo.setAttribute('color', colorAttr);

    const defaultPointSize = isLowPower ? 0.092 : 0.078;
    const mat = new THREE.PointsMaterial({
      color: 0xffffff,
      map: spriteTex,
      alphaTest: 0.01,
      vertexColors: true,
      size: defaultPointSize,
      transparent: true,
      opacity: 0,
      sizeAttenuation: true,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    });
    const particleSystem = new THREE.Points(geo, mat);
    particleSystem.frustumCulled = false;
    particleSystem.visible = false;
    masterGroup.add(particleSystem);

    // Continuous full-page ambient starfield (never clipped across sections)
    const bgCount = isLowPower ? 120 : 240;
    const bgPos = new Float32Array(bgCount * 3);
    for (let i = 0; i < bgCount; i++) {
      bgPos[i * 3] = (Math.random() - 0.5) * 18;
      bgPos[i * 3 + 1] = (Math.random() - 0.5) * 12;
      bgPos[i * 3 + 2] = (Math.random() - 0.5) * 8 - 2.5;
    }
    const bgBasePos = new Float32Array(bgPos);
    const bgGeo = new THREE.BufferGeometry();
    const bgPosAttr = new THREE.BufferAttribute(bgPos, 3);
    bgGeo.setAttribute('position', bgPosAttr);
    const bgMat = new THREE.PointsMaterial({
      color: 0x60a5fa,
      map: spriteTex,
      alphaTest: 0.01,
      size: 0.052,
      transparent: true,
      opacity: 0.36,
      sizeAttenuation: true,
      depthWrite: false
    });
    const bgStars = new THREE.Points(bgGeo, bgMat);
    bgStars.frustumCulled = false;
    scene.add(bgStars);

    const state = {
      activeShape: 'phone',
      targetColor: new THREE.Color('#3b82f6'),
      currentColor: new THREE.Color('#3b82f6'),
      particleOpacity: 0,
      layout: null,
      dissolveProgress: 0,
      phoneToPillMix: 0,
      isDigitizing: true,
      targetPos: new THREE.Vector3(isSmall ? 0 : 1.92, isSmall ? 0.45 : 0.12, 0),
      targetScale: isSmall ? 0.65 : 0.92,
      rotSpeed: 0.25,
      faceFront: true,
      pointerNDC: new THREE.Vector2(99, 99),
      smoothPointer: new THREE.Vector2(0, 0),
      pointerWorld: new THREE.Vector3(99, 99, 0),
      bgPointerWorld: new THREE.Vector3(99, 99, 0)
    };

    const flashColor = new THREE.Color('#e0f2fe');
    const buttonColor = new THREE.Color();
    const backgroundColor = new THREE.Color();
    const raycaster = new THREE.Raycaster();
    const zPlane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0);

    const syncTheme = () => {
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      mat.blending = isDark ? THREE.AdditiveBlending : THREE.NormalBlending;
      bgMat.opacity = isDark ? 0.36 : 0.24;
      flashColor.set(isDark ? '#e0f2fe' : '#0284c7');
      const themeStyles = getComputedStyle(document.documentElement);
      buttonColor.setStyle(themeStyles.getPropertyValue('--primary').trim());
      backgroundColor.set(isDark ? '#000000' : themeStyles.getPropertyValue('--bg-page').trim());
      mat.needsUpdate = true;
    };
    syncTheme();
    document.addEventListener('meddue-theme-change', syncTheme);

    let activeTouch = null;
    let touchEndedAt = null;
    if (!prefersReducedMotion) {
      const projectPointer = (event) => {
        state.pointerNDC.x = (event.clientX / window.innerWidth) * 2 - 1;
        state.pointerNDC.y = -(event.clientY / window.innerHeight) * 2 + 1;
      };
      const clearPointer = () => {
        activeTouch = null;
        touchEndedAt = null;
        state.pointerNDC.set(99, 99);
      };

      window.addEventListener('pointerdown', (event) => {
        if (event.pointerType !== 'touch' || !event.isPrimary) return;
        activeTouch = event.pointerId;
        touchEndedAt = null;
        projectPointer(event);
      }, { passive: true });
      window.addEventListener('pointermove', (event) => {
        if (event.pointerType === 'touch' && event.pointerId !== activeTouch) return;
        touchEndedAt = null;
        projectPointer(event);
      }, { passive: true });
      window.addEventListener('pointerup', (event) => {
        if (event.pointerId !== activeTouch) return;
        activeTouch = null;
        touchEndedAt = performance.now();
      }, { passive: true });
      window.addEventListener('pointercancel', (event) => {
        if (event.pointerId === activeTouch) clearPointer();
      }, { passive: true });
      document.documentElement.addEventListener('pointerleave', (event) => {
        if (event.pointerType !== 'touch') clearPointer();
      });
      window.addEventListener('blur', clearPointer);
    }

    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    }, { passive: true });

    let rafId = null;
    let prevTime = 0;
    let spinAngle = 0;
    let previousLayout = null;
    let faqEnteredAt = 0;
    const clock = new THREE.Clock();

    const tick = () => {
      if (document.hidden) {
        rafId = null;
        return;
      }

      const t = clock.getElapsedTime();
      const dt = Math.min(0.05, Math.max(0.001, t - prevTime));
      prevTime = t;
      const layout = state.layout;
      if (layout?.shape === 'questions' && previousLayout?.shape !== 'questions') faqEnteredAt = t;
      const groupShifts = layout && layout !== previousLayout && layout.shape === previousLayout?.shape
        ? layout.groups.map((group, i) => THREE.MathUtils.clamp(group.y - previousLayout.groups[i].y, -3, 3))
        : null;
      previousLayout = layout;

      // Interpolate group position, scale, color & opacity
      const layoutEase = 1 - Math.exp(-9 * dt);
      const followsLayout = layout || isArchitecturePage;
      masterGroup.position.lerp(state.targetPos, followsLayout ? layoutEase : 0.085);
      const nextScale = masterGroup.scale.x + (state.targetScale - masterGroup.scale.x) * (followsLayout ? layoutEase : 0.09);
      masterGroup.scale.setScalar(nextScale);

      state.currentColor.lerp(state.targetColor, isArchitecturePage ? layoutEase : 0.06);
      bgMat.color.copy(state.currentColor);

      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      const maxOp = isDark ? state.particleOpacity : state.particleOpacity * 0.78;
      mat.opacity += (maxOp - mat.opacity) * 0.14;
      mat.size += ((layout?.pointSize ?? defaultPointSize) - mat.size) * 0.11;

      // Group rotation: lock tightly to #hero-phone-3d during digitization, then spin smoothly into pill & pillars
      if (layout) {
        masterGroup.rotation.x *= 0.80;
        masterGroup.rotation.y *= 0.80;
        spinAngle = masterGroup.rotation.y;
      } else if (state.isDigitizing) {
        const compact = window.innerWidth <= 960;
        masterGroup.rotation.y += ((compact ? 0 : -0.227) - masterGroup.rotation.y) * 0.18;
        masterGroup.rotation.x += ((compact ? 0 : -0.07) - masterGroup.rotation.x) * 0.18;
        spinAngle = masterGroup.rotation.y;
      } else {
        const spinMult = state.activeShape === 'pill' && state.phoneToPillMix < 1
          ? Math.max(0.15, state.phoneToPillMix)
          : 1;
        spinAngle += dt * state.rotSpeed * spinMult;
        if (state.faceFront) {
          masterGroup.rotation.y += (Math.sin(t * 0.65) * 0.28 - masterGroup.rotation.y) * 0.06;
          masterGroup.rotation.x += (Math.cos(t * 0.5) * 0.12 - masterGroup.rotation.x) * 0.06;
        } else {
          masterGroup.rotation.y += (spinAngle - masterGroup.rotation.y) * 0.09;
          masterGroup.rotation.x += (Math.sin(t * 0.35) * 0.18 - masterGroup.rotation.x) * 0.06;
        }
      }

      // Project the cursor after updating the particle group's transform.
      const touchGain = touchEndedAt === null ? 1
        : 1 - THREE.MathUtils.smoothstep(performance.now() - touchEndedAt, 80, 420);
      const pointerActive = touchGain > 0 && Math.abs(state.pointerNDC.x) <= 1 && Math.abs(state.pointerNDC.y) <= 1;
      if (pointerActive) {
        state.smoothPointer.x += (state.pointerNDC.x * touchGain - state.smoothPointer.x) * 0.07;
        state.smoothPointer.y += (state.pointerNDC.y * touchGain - state.smoothPointer.y) * 0.07;
        raycaster.setFromCamera(state.pointerNDC, camera);
        raycaster.ray.intersectPlane(zPlane, state.pointerWorld);
        state.bgPointerWorld.copy(state.pointerWorld);
        masterGroup.worldToLocal(state.pointerWorld);
        bgStars.worldToLocal(state.bgPointerWorld);
      } else {
        state.smoothPointer.x *= 0.96;
        state.smoothPointer.y *= 0.96;
      }

      const pointerRepels = pointerActive && mat.opacity > 0.045;
      const isTouch = activeTouch !== null || touchEndedAt !== null;
      const screenSpacePointer = layout || isTouch;
      const unitsPerPixel = 2 * camera.position.z / (camera.projectionMatrix.elements[5] * window.innerHeight * nextScale);
      const pointerRadius = screenSpacePointer ? unitsPerPixel * (isTouch ? 132 : 154) : 1.26;
      const pointerStrength = (screenSpacePointer ? unitsPerPixel * (isTouch ? 59 : 70) : 0.66) * touchGain;

      // Morph particle positions + progressive digitization + continuous phone->pill blend + pointer repulsion
      const targetArr = shapes[state.activeShape] || shapes.pill;
      const phoneArr = shapes.phone;
      const pillArr = shapes.pill;
      const isBlendingToPill = state.activeShape === 'pill' && state.phoneToPillMix < 0.999;
      const mix = state.phoneToPillMix;
      const arc = isBlendingToPill ? Math.sin(mix * Math.PI) * 0.42 : 0;
      const lerpRate = followsLayout ? layoutEase : state.isDigitizing ? 0.14 : 0.095;
      const pos = posAttr.array;
      const colorArr = colorAttr.array;
      const dissolve = state.dissolveProgress;
      const assemblingPhone = layout?.shape === 'phone';
      const releasingPhone = !layout && (state.isDigitizing || isBlendingToPill);
      const isWave = layout?.shape === 'waves';
      const isScan = layout?.shape === 'scan';
      const isFaq = layout?.shape === 'questions';
      const scanY = Math.cos(t * 2.0) * 1.26;
      const faqTime = Math.max(0, t - faqEnteredAt - 0.42);
      const questionRotations = isFaq ? [
        [faqTime * 0.53 + 0.16, 0.22 * Math.sin(faqTime * 0.87)],
        [-faqTime * 0.44 - 0.20, 0.26 * Math.cos(faqTime * 0.70)],
        [0.34 * Math.sin(faqTime * 0.61), faqTime * 0.63 + 0.13]
      ].map(([yaw, pitch]) => ({
        sinY: Math.sin(yaw), cosY: Math.cos(yaw),
        sinX: Math.sin(pitch), cosX: Math.cos(pitch)
      })) : null;
      if (dissolve <= 0.005) {
        particleSystem.visible = false;
        wasBorn.fill(0);
      } else {
        particleSystem.visible = true;
        for (let i = 0; i < COUNT; i++) {
          const i3 = i * 3;
          if (dissolve < shapes.birthY[i]) {
            wasBorn[i] = 0;
            pos[i3] = phoneArr[i3];
            pos[i3 + 1] = phoneArr[i3 + 1];
            pos[i3 + 2] = 50;
            continue;
          }

          if (!wasBorn[i]) {
            wasBorn[i] = 1;
            pos[i3] = phoneArr[i3];
            pos[i3 + 1] = phoneArr[i3 + 1];
            pos[i3 + 2] = phoneArr[i3 + 2];
          }

          const age = Math.max(0, Math.min(1, (dissolve - shapes.birthY[i]) / 0.16));
          let flash = Math.max(0, 1 - age);
          let tint = state.currentColor;
          let intensity = 1;

          let tx;
          let ty;
          let tz;
          if (isBlendingToPill) {
            tx = phoneArr[i3] + (pillArr[i3] - phoneArr[i3]) * mix + shapes.driftVec[i3] * arc;
            ty = phoneArr[i3 + 1] + (pillArr[i3 + 1] - phoneArr[i3 + 1]) * mix + shapes.driftVec[i3 + 1] * arc;
            tz = phoneArr[i3 + 2] + (pillArr[i3 + 2] - phoneArr[i3 + 2]) * mix + shapes.driftVec[i3 + 2] * arc;
          } else {
            tx = targetArr[i3];
            ty = targetArr[i3 + 1];
            tz = targetArr[i3 + 2];
          }

          if (releasingPhone || assemblingPhone) {
            const phase = i * 2.4;
            const cloudX = shapes.phoneCloud[i * 2] + Math.sin(t + phase) * 0.11;
            const cloudY = shapes.phoneCloud[i * 2 + 1] + Math.cos(t * 0.8 + phase) * 0.14;

            if (releasingPhone) {
              // Keep the scan edge legible while points behind it drift into the cloud.
              const released = THREE.MathUtils.smoothstep(dissolve - shapes.birthY[i], 0, 0.42) * (1 - mix);
              const drift = released * (0.42 + Math.sin(t * 2.2 + phase) * 0.16);
              tx += (cloudX - phoneArr[i3]) * drift;
              ty += (cloudY - phoneArr[i3 + 1]) * drift;
              tz += shapes.driftVec[i3 + 2] * released * (0.65 + Math.sin(t * 1.9 + phase) * 0.45);
            } else {
              const start = (1 - shapes.birthY[i]) * 0.84;
              const settled = THREE.MathUtils.smoothstep(layout.formation, start, start + 0.16);
              tx = cloudX + (tx - cloudX) * settled;
              ty = cloudY + (ty - cloudY) * settled;
              flash = Math.max(0, 1 - Math.abs(layout.formation - start - 0.08) / 0.13) * 0.72;
            }
          }

          if (layout) {
            const isQrPoint = i % 5 < 3;
            const groupIndex = isFaq ? i % 3 : Number(isScan && !isQrPoint);
            const group = layout.groups[groupIndex];
            let depth = 0;
            if (isWave) {
              const phase = tx * 6 - t * 1.18 + ty * 2.9;
              ty += Math.sin(phase) * 0.17 + Math.cos(tx * 3.4 + t * 0.72) * 0.09;
              flash = (Math.sin(phase) + 1) * 0.20;
            } else if (isScan && isQrPoint) {
              const phase = t * 1.65 + i * 2.4;
              const spread = 0.07 + tz * tz * (group.spread - 0.07);
              const pulse = 0.032 * Math.sin(phase) + 0.026 * Math.sin(t * 1.4 + ty * 2);
              tx = tx * (1 + spread + pulse) + Math.sin(phase * 0.91) * 0.026;
              ty = i % 8 === 0 ? ty + scanY : ty * (1 + spread + pulse) + Math.cos(phase) * 0.024;
              flash = Math.max(0, 1 - Math.abs(ty - scanY) / 0.28) * 0.65;
              intensity = 0.95 - 0.56 * tz;
            } else if (isScan) {
              const life = (tz + t * (0.28 + (i % 9) * 0.013)) % 1;
              const roundedEnd = i % 8 < 3;
              const endRadius = group.scaleY / group.scaleX;
              const emission = (0.035 + life * 1.04) * (0.80 + tz * 0.35);
              const normalX = roundedEnd ? tx : 0;
              tx = roundedEnd
                ? Math.sign(tx) * (1 - endRadius) + tx * endRadius
                : tx * (1 - endRadius);
              tx += (normalX * emission + Math.sin(i * 2.4 + t * 1.8) * 0.13 * life) * endRadius;
              ty *= 1 + emission;
              tint = buttonColor;
              flash = (1 - life) * 0.36;
              intensity = THREE.MathUtils.smoothstep(life, 0, 0.12) *
                (1 - THREE.MathUtils.smoothstep(life, 0.55, 1));
            } else if (isFaq) {
              const { sinY, cosY, sinX, cosX } = questionRotations[groupIndex];
              const phase = t * 1.8 + i * 2.4;
              tx += Math.sin(phase) * 0.037;
              ty += Math.cos(phase * 0.89) * 0.048;
              tz += Math.sin(phase * 0.78) * 0.085;
              const x = tx * cosY + tz * sinY;
              const z = tz * cosY - tx * sinY;
              tx = x;
              depth = (ty * sinX + z * cosX) * group.scaleX;
              ty = ty * cosX - z * sinX + Math.sin(t * 0.92 + groupIndex * 1.8) * 0.12;
              flash = 0.20 + Math.sin(phase) * 0.15;
              intensity = 0.78 + THREE.MathUtils.clamp(depth / group.scaleX, -0.4, 0.4) * 0.45;
            }

            tx = group.x * (1 - depth / camera.position.z) + tx * group.scaleX;
            ty = group.y * (1 - depth / camera.position.z) + ty * group.scaleY;
            tz = depth;
            if (groupShifts) pos[i3 + 1] += groupShifts[groupIndex];
          }

          if (pointerRepels) {
            // Work in the layout's final coordinates so anchored effects react to the cursor in place.
            const perspective = layout ? 1 - tz / camera.position.z : 1;
            const dx = (layout ? tx : pos[i3]) - state.pointerWorld.x * perspective;
            const dy = (layout ? ty : pos[i3 + 1]) - state.pointerWorld.y * perspective;
            const dz = layout ? 0 : pos[i3 + 2] - state.pointerWorld.z;
            const distanceSquared = dx * dx + dy * dy + dz * dz;
            if (distanceSquared < pointerRadius * pointerRadius && distanceSquared > 0.0001) {
              const distance = Math.sqrt(distanceSquared);
              const proximity = 1 - distance / pointerRadius;
              const falloff = screenSpacePointer ? proximity * (0.35 + proximity * 0.65) : proximity;
              const released = state.isDigitizing ? age : 1;
              const push = pointerStrength * falloff * released / distance;
              tx += dx * push;
              ty += dy * push;
              tz += dz * push;
            }
          }

          const red = tint.r + (flashColor.r - tint.r) * flash;
          const green = tint.g + (flashColor.g - tint.g) * flash;
          const blue = tint.b + (flashColor.b - tint.b) * flash;
          colorArr[i3] = backgroundColor.r + (red - backgroundColor.r) * intensity;
          colorArr[i3 + 1] = backgroundColor.g + (green - backgroundColor.g) * intensity;
          colorArr[i3 + 2] = backgroundColor.b + (blue - backgroundColor.b) * intensity;
          pos[i3] += (tx - pos[i3]) * lerpRate;
          pos[i3 + 1] += (ty - pos[i3 + 1]) * lerpRate;
          pos[i3 + 2] += (tz - pos[i3 + 2]) * lerpRate;
        }
        posAttr.needsUpdate = true;
        colorAttr.needsUpdate = true;
      }

      // Ambient starfield parallax
      bgStars.rotation.y = t * 0.016 + state.smoothPointer.x * 0.12;
      bgStars.rotation.x = -state.smoothPointer.y * 0.08;
      bgStars.position.x = -state.smoothPointer.x * 0.32;
      bgStars.position.y = -state.smoothPointer.y * 0.22;

      const bgArr = bgPosAttr.array;
      for (let i = 0; i < bgCount; i++) {
        const i3 = i * 3;
        let tx = bgBasePos[i3];
        let ty = bgBasePos[i3 + 1];
        if (pointerActive) {
          const dx = bgArr[i3] - state.bgPointerWorld.x;
          const dy = bgArr[i3 + 1] - state.bgPointerWorld.y;
          const dSq = dx * dx + dy * dy;
          if (dSq < 4.0 && dSq > 0.0001) {
            const dist = Math.sqrt(dSq);
            const push = (2.0 - dist) * 0.38 * touchGain;
            tx += (dx / dist) * push;
            ty += (dy / dist) * push;
          }
        }
        bgArr[i3] += (tx - bgArr[i3]) * 0.06;
        bgArr[i3 + 1] += (ty - bgArr[i3 + 1]) * 0.06;
      }
      bgPosAttr.needsUpdate = true;

      renderer.render(scene, camera);
      if (!prefersReducedMotion) {
        rafId = requestAnimationFrame(tick);
      }
    };

    const start = () => {
      if (prefersReducedMotion) {
        renderer.render(scene, camera);
        return;
      }
      if (!rafId && !document.hidden) {
        clock.start();
        rafId = requestAnimationFrame(tick);
      }
    };

    document.addEventListener('visibilitychange', () => {
      if (document.hidden && rafId) {
        cancelAnimationFrame(rafId);
        rafId = null;
      } else if (!document.hidden) {
        start();
      }
    });

    const snapShape = (name) => {
      const arr = shapes[name];
      if (!arr) return;
      posAttr.array.set(arr);
      posAttr.needsUpdate = true;
      wasBorn.fill(1);
    };

    start();

    return { state, masterGroup, camera, raycaster, zPlane, snapShape };
  }

  // --- 4b. HERO 3D PHONE SHOWCASE (RECETA / CALENDARIO / PROGRESO) ---
  function initHeroPhoneShowcase() {
    const phone = $('#hero-phone-3d');
    const screens = $$('.hp-screen');
    const navBtns = $$('.hp-nav-btn');
    if (!phone || !screens.length) return;

    const order = ['receta', 'calendario', 'progreso'];
    let currentIdx = 0;
    let pauseUntil = 0;

    const setScreen = (key) => {
      const idx = order.indexOf(key);
      if (idx !== -1) currentIdx = idx;
      screens.forEach((s) => s.classList.toggle('is-active', s.getAttribute('data-phone-screen') === key));
      navBtns.forEach((b) => {
        const match = b.getAttribute('data-phone-tab') === key;
        b.classList.toggle('is-active', match);
        b.setAttribute('aria-selected', match ? 'true' : 'false');
      });
    };

    navBtns.forEach((btn) => {
      btn.addEventListener('click', () => {
        const target = btn.getAttribute('data-phone-tab');
        if (target) {
          setScreen(target);
          pauseUntil = Date.now() + 10000;
        }
      });
    });

    if (!prefersReducedMotion) {
      setInterval(() => {
        if (document.hidden || Date.now() < pauseUntil) return;
        currentIdx = (currentIdx + 1) % order.length;
        setScreen(order[currentIdx]);
      }, 4500);

      // Subtle desktop pointer tilt
      if (window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
        const stage = $('.hero-device-stage');
        if (stage) {
          stage.addEventListener('pointermove', (e) => {
            const rect = stage.getBoundingClientRect();
            const nx = ((e.clientX - rect.left) / rect.width - 0.5) * 2;
            const ny = ((e.clientY - rect.top) / rect.height - 0.5) * 2;
            phone.style.setProperty('--tilt-y', `${(-13 + nx * 4).toFixed(2)}deg`);
            phone.style.setProperty('--tilt-x', `${(4 - ny * 3).toFixed(2)}deg`);
          }, { passive: true });
          stage.addEventListener('pointerleave', () => {
            phone.style.removeProperty('--tilt-y');
            phone.style.removeProperty('--tilt-x');
          }, { passive: true });
        }
      }
    }
  }

  // --- 5. HERO Y CAPÍTULOS ---
  function initScrollytelling(threeCtrl, getLenis) {
    const hero = $('#hero');
    const story = $('#story');
    const steps = $$('.story-step');
    const cards = $$('.story-dock-card');
    const dots = $$('.story-dot');
    const counter = $('#story-chapter-counter');
    const heroPhone = $('#hero-phone-3d');
    const heroMaskWrap = $('#hp-mask-wrap');
    const heroShadow = $('.hero-phone-shadow');
    const heroBeam = $('#hp-dissolve-beam');
    const storyWaveCap = $('.story-wave-cap');
    const dockBar = $('.story-dock-bar');
    const dockStack = $('.story-dock-stack');

    const compactView = window.matchMedia('(max-width: 960px)');
    const isSmallInit = compactView.matches;
    const storySlotPos = threeCtrl ? new window.THREE.Vector3(isSmallInit ? 0 : 1.92, isSmallInit ? 0.45 : 0.92, 0) : null;
    let storySlotScale = isSmallInit ? 0.62 : 0.76;
    let activePillarIdx = 0;
    let syncStorySlot = () => {};
    let syncStoryFromViewport = () => {};
    let lowerActive = false;

    const chapterStart = (index) => compactView.matches ? 76 : index === 0 ? 42 : 56;
    const PILLAR_CONFIG = [
      { shape: 'pill', color: '#3b82f6', accent: 'blue', rotSpeed: 0.28, faceFront: false },
      { shape: 'neural', color: '#22d3ee', accent: 'cyan', rotSpeed: 0.25, faceFront: false },
      { shape: 'heart', color: '#a78bfa', accent: 'purple', rotSpeed: 0.2, faceFront: true },
      { shape: 'chart', color: '#10b981', accent: 'emerald', rotSpeed: 0.18, faceFront: true }
    ];

    const activate = (idx, revealParticles = false) => {
      if (!steps.length) return;
      const safe = Math.max(0, Math.min(idx, steps.length - 1));
      activePillarIdx = safe;
      steps.forEach((s, i) => s.classList.toggle('is-active', i === safe));
      cards.forEach((c, i) => c.classList.toggle('is-active', i === safe));
      dots.forEach((d, i) => d.classList.toggle('is-active', i === safe));
      if (counter) counter.textContent = `0${safe + 1} / 0${steps.length}`;

      const cfg = PILLAR_CONFIG[safe] || PILLAR_CONFIG[0];
      if (story) story.setAttribute('data-accent', cfg.accent);
      if (threeCtrl && !lowerActive) {
        threeCtrl.state.activeShape = cfg.shape;
        threeCtrl.state.targetColor.set(cfg.color);
        threeCtrl.state.rotSpeed = cfg.rotSpeed;
        threeCtrl.state.faceFront = cfg.faceFront;
        if (revealParticles) {
          threeCtrl.state.dissolveProgress = 1.35;
          threeCtrl.state.particleOpacity = 0.96;
          if (safe > 0 || (story && story.getBoundingClientRect().top <= 0)) {
            syncStorySlot();
            threeCtrl.state.isDigitizing = false;
            threeCtrl.state.phoneToPillMix = 1;
            threeCtrl.state.targetPos.copy(storySlotPos);
            threeCtrl.state.targetScale = storySlotScale;
          }
        }
      }
    };

    dots.forEach((dot, idx) => {
      dot.addEventListener('click', () => {
        activate(idx, true);
        if (threeCtrl && !lowerActive) {
          threeCtrl.state.isDigitizing = false;
          threeCtrl.state.phoneToPillMix = 1;
          threeCtrl.state.targetPos.copy(storySlotPos);
          threeCtrl.state.targetScale = storySlotScale;
        }
        const step = steps[idx];
        if (!step) return;
        const offset = -window.innerHeight * (chapterStart(idx) - 4) / 100;
        const lenis = getLenis();
        if (lenis) {
          lenis.scrollTo(step, { offset });
        } else {
          const top = Math.max(0, step.getBoundingClientRect().top + window.scrollY + offset);
          window.scrollTo({ top, behavior: prefersReducedMotion ? 'auto' : 'smooth' });
        }
      });
    });

    activate(0, false);

    const hideHero = () => {
      hero.style.visibility = 'hidden';
      if (heroPhone) heroPhone.style.opacity = '0';
      if (heroBeam) heroBeam.style.opacity = '0';
      if (heroShadow) heroShadow.style.opacity = '0';
    };

    const setLowerActive = (active) => {
      if (lowerActive === active) return;
      lowerActive = active;
      if (active) hideHero();
      else syncStoryFromViewport();
    };

    if (prefersReducedMotion) return;
    const { gsap, ScrollTrigger } = window;
    const hasScrollTrigger = Boolean(gsap && ScrollTrigger);
    const usesNativeStory = () => compactView.matches || !hasScrollTrigger;
    if (hasScrollTrigger) gsap.registerPlugin(ScrollTrigger);

    if (threeCtrl) {
      story.classList.add('has-particle-chapters');
      const { camera, state } = threeCtrl;
      const { clamp, smoothstep } = window.THREE.MathUtils;
      const phoneOriginPos = new window.THREE.Vector3();
      let phoneOriginScale = 0.92;
      let snapStoryOnArrival = window.location.hash === '#story';
      const viewHeight = 2 * Math.tan(camera.fov * Math.PI / 360) * camera.position.z;

      const syncPhoneOrigin = () => {
        if (!heroPhone) return;
        const rect = heroPhone.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        threeCtrl.camera.updateMatrixWorld();
        const cx = rect.left + rect.width * 0.5;
        const cy = rect.top + rect.height * 0.5;
        const ndc = new window.THREE.Vector2(
          (cx / window.innerWidth) * 2 - 1,
          -(cy / window.innerHeight) * 2 + 1
        );
        threeCtrl.raycaster.setFromCamera(ndc, threeCtrl.camera);
        threeCtrl.raycaster.ray.intersectPlane(threeCtrl.zPlane, phoneOriginPos);
        phoneOriginScale = rect.height / window.innerHeight * viewHeight / 3.55;
      };

      syncStorySlot = () => {
        if (compactView.matches) {
          const step = steps[activePillarIdx];
          const rect = step.getBoundingClientRect();
          const slotHeight = parseFloat(getComputedStyle(step).marginTop);
          const unit = viewHeight / window.innerHeight;
          const centerY = rect.top - slotHeight / 2;
          storySlotPos.set((rect.left + rect.width / 2 - window.innerWidth / 2) * unit,
            (window.innerHeight / 2 - centerY) * unit, 0);
          storySlotScale = (slotHeight - 24) * unit / 3.9;
          return;
        }
        const barRect = dockBar.getBoundingClientRect();
        if (!barRect.width) return;
        threeCtrl.camera.updateMatrixWorld();
        const barH = dockBar.offsetHeight || 43;
        const stackH = dockStack ? (dockStack.offsetHeight || 189) : 189;
        const colH = window.innerHeight - 108;
        const stickyBarTop = 80 + colH - (barH + 10 + stackH);
        const slotCx = barRect.left + barRect.width * 0.5;
        const availH = Math.max(170, stickyBarTop - 104);
        const slotCy = 72 + (stickyBarTop - 96) * 0.5;
        const ndc = new window.THREE.Vector2(
          (slotCx / window.innerWidth) * 2 - 1,
          -(slotCy / window.innerHeight) * 2 + 1
        );
        threeCtrl.raycaster.setFromCamera(ndc, threeCtrl.camera);
        threeCtrl.raycaster.ray.intersectPlane(threeCtrl.zPlane, storySlotPos);
        storySlotScale = clamp(availH / window.innerHeight * viewHeight / 3.9, 0.58, 0.90);
      };

      const resetPhoneVisual = () => {
        if (heroMaskWrap) {
          heroMaskWrap.style.maskImage = 'none';
          heroMaskWrap.style.webkitMaskImage = 'none';
        }
        if (heroPhone) {
          heroPhone.style.maskImage = 'none';
          heroPhone.style.webkitMaskImage = 'none';
          heroPhone.style.opacity = '1';
          heroPhone.style.filter = 'none';
          heroPhone.style.scale = '1';
        }
        if (heroBeam) heroBeam.style.opacity = '0';
        if (heroShadow) heroShadow.style.opacity = '1';
      };

      // Initial Hero state: zero visible particles behind HTML phone (no double figure)
      syncPhoneOrigin();
      syncStorySlot();
      resetPhoneVisual();
      threeCtrl.state.activeShape = 'phone';
      threeCtrl.state.particleOpacity = 0;
      threeCtrl.state.dissolveProgress = 0;
      threeCtrl.state.phoneToPillMix = 0;
      threeCtrl.state.isDigitizing = true;
      threeCtrl.state.faceFront = true;
      threeCtrl.state.targetPos.copy(phoneOriginPos);
      threeCtrl.state.targetScale = phoneOriginScale;
      threeCtrl.masterGroup.position.copy(phoneOriginPos);
      threeCtrl.masterGroup.scale.setScalar(phoneOriginScale);
      threeCtrl.masterGroup.rotation.set(-0.07, -0.227, 0);

      const updateHeroTransition = (p) => {
        if (lowerActive) return;
        const storyTop = story.getBoundingClientRect().top;
        if (p >= 1 || storyTop <= HEADER_SCROLL_OFFSET + 1) {
          showStoryFigure();
          return;
        }
        if (hero.style.visibility === 'hidden') hero.style.visibility = 'visible';
        const phoneRect = heroPhone ? heroPhone.getBoundingClientRect() : null;
        const waveRect = storyWaveCap ? storyWaveCap.getBoundingClientRect() : null;
        const waveCrestY = waveRect
          ? waveRect.top + waveRect.height * 0.42
          : storyTop;
        const waveProgress = phoneRect && phoneRect.height
          ? Math.max(0, Math.min(1, (phoneRect.bottom - waveCrestY) / phoneRect.height))
          : Math.max(0, Math.min(1, (p - 0.01) / 0.55));
        const compact = compactView.matches;
        const compactScanEnd = 0.28;
        // The phone and wave scroll together on smaller screens.
        const d = compact ? smoothstep(p, 0.01, compactScanEnd) : waveProgress;

        if (compact) syncPhoneOrigin();

        if (p <= 0.005 || d <= 0.002) {
          if (!compact) syncPhoneOrigin();
          resetPhoneVisual();
          threeCtrl.state.particleOpacity = 0;
          threeCtrl.state.dissolveProgress = 0;
          threeCtrl.state.phoneToPillMix = 0;
          threeCtrl.state.isDigitizing = true;
          threeCtrl.state.activeShape = 'phone';
          threeCtrl.state.faceFront = true;
          threeCtrl.state.targetPos.copy(phoneOriginPos);
          threeCtrl.state.targetScale = phoneOriginScale;
          return;
        }

        if (heroPhone) {
          const maskTarget = heroMaskWrap || heroPhone;
          const phoneH = heroPhone.offsetHeight || 563;
          const bottomPad = heroMaskWrap
            ? Math.max(0, heroMaskWrap.offsetHeight - (heroPhone.offsetTop + phoneH))
            : 0;
          const cutPx = d <= 0.001 ? 0 : bottomPad + phoneH * d;
          const edgePx = cutPx + 34;
          const maskGrad = d >= 0.99
            ? 'linear-gradient(to top, transparent 0%, transparent 100%)'
            : `linear-gradient(to top, transparent 0px, transparent ${cutPx.toFixed(1)}px, black ${edgePx.toFixed(1)}px, black 100%)`;

          maskTarget.style.maskImage = d <= 0.001 ? 'none' : maskGrad;
          maskTarget.style.webkitMaskImage = d <= 0.001 ? 'none' : maskGrad;
          heroPhone.style.maskImage = 'none';
          heroPhone.style.webkitMaskImage = 'none';
          heroPhone.style.opacity = d >= 0.99 ? '0' : '1';
          heroPhone.style.filter = 'none';
          heroPhone.style.scale = '1';

          if (heroBeam) {
            const phoneTopInStage = (heroMaskWrap ? heroMaskWrap.offsetTop : 0) + heroPhone.offsetTop;
            heroBeam.style.top = `${(phoneTopInStage + phoneH * (1 - d)).toFixed(1)}px`;
            heroBeam.style.opacity = d > 0.02 && d < 0.96 ? String((Math.sin(d * Math.PI) * 0.95).toFixed(3)) : '0';
          }
        }

        if (heroShadow) {
          heroShadow.style.opacity = String(Math.max(0, 1 - d * 3.2));
        }

        threeCtrl.state.particleOpacity = Math.min(1, d / 0.08) * 0.96;

        if (d < 0.995) {
          threeCtrl.state.dissolveProgress = d;
          threeCtrl.state.isDigitizing = true;
          threeCtrl.state.phoneToPillMix = 0;
          threeCtrl.state.activeShape = 'phone';
          threeCtrl.state.faceFront = true;
          threeCtrl.state.targetColor.set('#3b82f6');
          threeCtrl.state.targetPos.copy(phoneOriginPos);
          threeCtrl.state.targetScale = phoneOriginScale;
        } else {
          // Phase 2: phone is 100% digitized; continuously morph into 3D Pill while Pillar 01 is active
          const waveDistance = phoneRect ? phoneRect.top - waveCrestY : 0;
          const waveTravel = clamp(waveDistance + storyTop - HEADER_SCROLL_OFFSET, 1, 260);
          const waveMix = phoneRect ? clamp(waveDistance / waveTravel, 0, 1) : clamp((p - 0.62) / 0.38, 0, 1);
          const rawM = compact ? clamp((p - compactScanEnd) / 0.48, 0, 1) : waveMix;
          const m = rawM * rawM * (3 - 2 * rawM);
          threeCtrl.state.dissolveProgress = 1.0 + rawM * 0.35;
          threeCtrl.state.isDigitizing = false;
          if (compact) syncStorySlot();
          if (activePillarIdx === 0) {
            threeCtrl.state.activeShape = 'pill';
            threeCtrl.state.phoneToPillMix = m;
            threeCtrl.state.faceFront = false;
            threeCtrl.state.targetColor.set('#3b82f6');
            threeCtrl.state.targetPos.set(
              phoneOriginPos.x + (storySlotPos.x - phoneOriginPos.x) * m,
              phoneOriginPos.y + (storySlotPos.y - phoneOriginPos.y) * m,
              0
            );
            threeCtrl.state.targetScale = phoneOriginScale + (storySlotScale - phoneOriginScale) * m;
          } else {
            threeCtrl.state.phoneToPillMix = 1;
            threeCtrl.state.targetPos.copy(storySlotPos);
            threeCtrl.state.targetScale = storySlotScale;
          }
        }
      };

      const showStoryFigure = () => {
        if (lowerActive) return;
        if (state.activeShape !== PILLAR_CONFIG[activePillarIdx].shape) activate(activePillarIdx, false);
        hideHero();
        syncStorySlot();
        state.isDigitizing = false;
        state.phoneToPillMix = 1;
        state.dissolveProgress = 1.35;
        state.particleOpacity = 0.96;
        state.targetPos.copy(storySlotPos);
        state.targetScale = storySlotScale;

        if (snapStoryOnArrival) {
          snapStoryOnArrival = false;
          threeCtrl.snapShape(state.activeShape);
          state.currentColor.copy(state.targetColor);
          threeCtrl.masterGroup.position.copy(storySlotPos);
          threeCtrl.masterGroup.scale.setScalar(storySlotScale);
        }
      };

      // Derive the current scene from the viewport, including on direct links and history restores.
      syncStoryFromViewport = () => {
        if (lowerActive) return;
        const height = window.innerHeight;
        const storyTop = story.getBoundingClientRect().top;
        const progress = clamp((height - storyTop) / (height * 1.1), 0, 1);
        const chapter = Math.max(0, steps.findLastIndex((step, index) =>
          step.getBoundingClientRect().top <= height * chapterStart(index) / 100
        ));
        if (chapter !== activePillarIdx) activate(chapter, false);
        if (progress < 1 && chapter === 0 && storyTop > HEADER_SCROLL_OFFSET + 1) {
          updateHeroTransition(progress);
        } else {
          showStoryFigure();
        }
      };
      let storyFrame = 0;
      const queueStorySync = () => {
        if (storyFrame) return;
        storyFrame = requestAnimationFrame(() => {
          storyFrame = 0;
          syncStoryFromViewport();
        });
      };
      window.addEventListener('scroll', () => {
        if (usesNativeStory()) queueStorySync();
      }, { passive: true });
      window.addEventListener('resize', () => {
        syncPhoneOrigin();
        syncStorySlot();
        queueStorySync();
      }, { passive: true });
      window.addEventListener('pageshow', queueStorySync);
      window.addEventListener('hashchange', queueStorySync);
      document.fonts?.ready.then(queueStorySync);
      queueStorySync();

      if (hasScrollTrigger) {
        ScrollTrigger.create({
          trigger: story,
          start: 'top bottom',
          end: 'top -10%',
          scrub: true,
          onUpdate: ({ progress }) => {
            if (!usesNativeStory()) updateHeroTransition(progress);
          },
          onLeave: () => {
            if (!usesNativeStory()) showStoryFigure();
          }
        });
      }
    }

    if (hasScrollTrigger) {
      steps.forEach((step, idx) => {
        ScrollTrigger.create({
          trigger: step,
          start: () => `top ${chapterStart(idx)}%`,
          end: 'bottom 44%',
          onEnter: () => {
            if (!usesNativeStory()) activate(idx, true);
          },
          onLeaveBack: () => {
            if (idx > 0 && !usesNativeStory()) activate(idx - 1, true);
          }
        });
      });
    }
    if (threeCtrl) initLowerParticles(threeCtrl, setLowerActive);
  }

  function initLowerParticles(threeCtrl, setLowerActive) {
    const app = $('#app');
    const device = $('.showcase-device', app);
    const phone = $('.showcase-phone', device);
    const pricing = $('#pricing');
    const download = $('.download-layout');
    const qr = $('#download-qr-image');
    const downloadButton = $('#main-download-btn');
    const faq = $('#faq');
    const faqTitle = $('h3', faq);
    const about = $('#about');
    const aboutHeader = $('.section-header', about);
    about.classList.add('has-particle-globe');
    const { camera, state } = threeCtrl;
    const { clamp, smoothstep } = window.THREE.MathUtils;
    let frame = 0;

    const sync = () => {
      frame = 0;
      const width = window.innerWidth;
      const height = window.innerHeight;
      const unit = 2 * Math.tan(camera.fov * Math.PI / 360) * camera.position.z / height;
      const groupAt = (x, y, scaleX, scaleY) => ({
        x: (x - width * 0.5) * unit,
        y: (height * 0.5 - y) * unit,
        scaleX: scaleX * unit,
        scaleY: scaleY * unit
      });
      const groupAtRect = (rect) => groupAt(
        rect.left + rect.width / 2,
        rect.top + rect.height / 2,
        rect.width / 2,
        rect.height / 2
      );

      const appRect = app.getBoundingClientRect();
      const priceRect = pricing.getBoundingClientRect();
      const downloadRect = download.getBoundingClientRect();
      const faqRect = faq.getBoundingClientRect();
      const aboutRect = about.getBoundingClientRect();
      const phoneRect = phone.getBoundingClientRect();
      const entrance = Math.min(height * 0.91, height * 0.77 + phoneRect.top - appRect.top);
      const completion = Math.min(entrance * 0.55, Math.max(84, height - phoneRect.height - 100));
      const progress = clamp((entrance - phoneRect.top) / (entrance - completion), 0, 1);
      const formation = smoothstep(progress, 0.02, 0.86);
      const reveal = smoothstep(progress, 0.34, 1);
      const fade = smoothstep(priceRect.top / height, 0.54, 0.70);
      const isRevealing = reveal > 0 && reveal < 1;
      phone.classList.toggle('is-assembling', isRevealing);
      device.style.setProperty('--showcase-reveal', `${(reveal * 100).toFixed(2)}%`);
      device.style.setProperty('--showcase-phone-opacity', reveal > 0 ? fade.toFixed(3) : '0');
      device.style.setProperty('--showcase-beam-opacity', (isRevealing ? Math.sin(reveal * Math.PI) * 0.86 : 0).toFixed(3));

      if (appRect.top > height * 0.77) {
        state.layout = null;
        setLowerActive(false);
        return;
      }

      setLowerActive(true);
      state.isDigitizing = false;
      state.phoneToPillMix = 1;
      state.dissolveProgress = 1.35;
      state.rotSpeed = 0.20;
      state.faceFront = true;
      state.targetPos.set(0, 0, 0);
      state.targetScale = 1;

      const setLayout = (shape, color, opacity, pointSize, groups) => {
        state.activeShape = shape;
        state.targetColor.set(color);
        state.particleOpacity = opacity;
        state.layout = { shape, pointSize, groups };
      };

      if (aboutRect.top <= height * 0.62) {
        state.activeShape = 'globe';
        state.targetColor.set('#a78bfa');
        state.faceFront = false;
        state.layout = null;
        if (width <= 960) {
          const headerRect = aboutHeader.getBoundingClientRect();
          const slotHeight = parseFloat(getComputedStyle(aboutHeader).paddingTop);
          const slotCenter = headerRect.top + slotHeight / 2;
          state.particleOpacity = 0.76;
          state.targetScale = (slotHeight - 22) * unit / 3.9;
          state.targetPos.set(0, (height / 2 - slotCenter) * unit, 0);
        } else {
          state.particleOpacity = 0.34;
          state.targetScale = 0.76;
          state.targetPos.set(-2.85, 0.10, 0);
        }
      } else if (faqRect.top <= height * 0.74) {
        const titleY = faqTitle.getBoundingClientRect().top;
        const gutter = faqRect.left;
        const sides = gutter >= 96;
        const side = sides ? Math.min(110, gutter * 0.49) : Math.min(56, width * 0.13);
        const radius = sides ? Math.min(60, gutter * 0.31) : 20;
        const firstY = sides ? titleY + 92 : titleY - 28;
        const secondY = sides ? titleY + 164 : titleY - 17;
        setLayout('questions', '#8b5cf6', 0.74, 0.055, [
          groupAt(side, firstY, radius, radius),
          groupAt(width - side, secondY, radius * 0.84, radius * 0.84),
          groupAt(sides ? side + 30 : width * 0.5, sides ? titleY + 246 : titleY - 35, radius * 0.54, radius * 0.54)
        ]);
      } else if (downloadRect.top <= height * 0.74) {
        const rect = qr.getBoundingClientRect();
        const halo = groupAtRect(rect);
        const horizontalSpace = Math.min(rect.left, width - rect.right);
        halo.spread = clamp(horizontalSpace - 12, 0, 104) / (rect.width / 2);
        setLayout('scan', '#0ea5a4', 0.91, 0.057, [
          halo,
          groupAtRect(downloadButton.getBoundingClientRect())
        ]);
      } else if (priceRect.top <= height * 0.66) {
        const visibleTop = Math.max(priceRect.top, 64);
        const visibleBottom = Math.min(priceRect.bottom, height);
        const waveHeight = Math.min(priceRect.height * 0.49, height * 0.51);
        setLayout('waves', '#6366f1', 0.51, 0.048, [
          groupAt(width * 0.5, (visibleTop + visibleBottom) * 0.5, width * 0.52, waveHeight)
        ]);
      } else {
        const lift = width > 960 ? (1 - smoothstep(progress, 0, 0.30)) * Math.min(96, height * 0.10) : 0;
        const opacity = (0.36 + formation * 0.60) * (1 - reveal * fade);
        setLayout('phone', '#38bdf8', opacity, 0.071, [
          groupAt(
            phoneRect.left + phoneRect.width / 2,
            phoneRect.top - lift + phoneRect.height / 2,
            (phoneRect.width / 2 + 3) / 0.905,
            (phoneRect.height / 2 + 3) / 1.775
          )
        ]);
        state.layout.formation = formation;
      }
    };

    const queueSync = () => {
      if (!frame) frame = requestAnimationFrame(sync);
    };
    window.addEventListener('scroll', queueSync, { passive: true });
    window.addEventListener('resize', queueSync, { passive: true });
    const observer = new ResizeObserver(queueSync);
    [app, pricing, download, faq].forEach((section) => observer.observe(section));
    window.addEventListener('pageshow', queueSync);
    window.addEventListener('hashchange', queueSync);
    sync();
  }

  // --- 6. DEMOSTRACIÓN DE MEDDUE ---
  function initShowcase() {
    const tabs = $$('.showcase-tab');
    const slides = $$('.showcase-slide');
    const videos = $$('.showcase-video');
    let currentSlide = 0;
    let inView = false;

    const syncVideos = () => {
      videos.forEach((video, index) => {
        if (!inView || document.hidden || index !== currentSlide) {
          video.pause();
        } else if (!prefersReducedMotion) {
          video.play().catch(() => {});
        }
      });
    };

    const selectSlide = (index) => {
      currentSlide = index;
      tabs.forEach((tab, i) => {
        const selected = i === index;
        tab.classList.toggle('active', selected);
        tab.setAttribute('aria-selected', selected ? 'true' : 'false');
        tab.tabIndex = selected ? 0 : -1;
        slides[i].hidden = !selected;
      });
      syncVideos();
    };

    tabs.forEach((tab, i) => {
      tab.addEventListener('click', () => selectSlide(i));
      tab.addEventListener('keydown', (event) => {
        const next = {
          ArrowRight: (i + 1) % tabs.length,
          ArrowLeft: (i + tabs.length - 1) % tabs.length,
          ArrowDown: (i + 1) % tabs.length,
          ArrowUp: (i + tabs.length - 1) % tabs.length,
          Home: 0,
          End: tabs.length - 1
        }[event.key];
        if (next === undefined) return;
        event.preventDefault();
        selectSlide(next);
        tabs[next].focus();
      });
    });

    const observer = new IntersectionObserver(([entry]) => {
      inView = entry.isIntersecting && entry.intersectionRatio >= 0.35;
      syncVideos();
    }, { threshold: 0.35 });
    observer.observe($('.showcase-device'));
    document.addEventListener('visibilitychange', syncVideos);
    videos.forEach((video) => { video.controls = prefersReducedMotion; });
    selectSlide(0);
  }

  // --- 7. FAQ, GITHUB LATEST RELEASE & CONTACT FORM ---
  function initFaqAndForms() {
    $$('.faq-trigger').forEach((trigger) => {
      trigger.addEventListener('click', () => {
        const item = trigger.closest('.faq-item');
        if (!item) return;
        const wasActive = item.classList.contains('active');
        $$('.faq-item').forEach((f) => {
          f.classList.remove('active');
          const b = $('.faq-trigger', f);
          if (b) b.setAttribute('aria-expanded', 'false');
        });
        if (!wasActive) {
          item.classList.add('active');
          trigger.setAttribute('aria-expanded', 'true');
        }
      });
    });

    // Latest GitHub APK metadata (silent fallback to v2.38.0 if offline/rate-limited)
    fetch('https://api.github.com/repos/JDkinior/MediTime/releases/latest', {
      headers: { Accept: 'application/vnd.github.v3+json' }
    })
      .then((r) => (r.ok ? r.json() : null))
      .then((rel) => {
        if (!rel || !rel.tag_name) return;
        const apk = Array.isArray(rel.assets) ? rel.assets.find((a) => a.name && a.name.endsWith('.apk')) : null;
        const url = apk ? apk.browser_download_url : rel.html_url;
        const verEl = $('#download-meta-version');
        const mainBtn = $('#main-download-btn');
        const heroBtn = $('#hero-download-btn');
        if (verEl) verEl.textContent = rel.tag_name;
        if (mainBtn && url) mainBtn.href = url;
        if (heroBtn && url) heroBtn.setAttribute('title', `Descargar MedDue ${rel.tag_name}`);
      })
      .catch(() => {});

    const form = $('#contact-form');
    const status = $('#form-status');
    if (form) {
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const btn = $('button[type="submit"]', form);
        const orig = btn ? btn.innerHTML : '';
        if (btn) {
          btn.disabled = true;
          btn.textContent = 'Enviando...';
        }
        try {
          const res = await fetch(form.action, {
            method: 'POST',
            body: new FormData(form),
            headers: { Accept: 'application/json' }
          });
          if (!res.ok) throw new Error('HTTP error');
          if (status) {
            status.className = 'form-status success';
            status.textContent = '¡Gracias! Tu mensaje fue enviado al equipo de MedDue.';
          }
          form.reset();
        } catch {
          if (status) {
            status.className = 'form-status error';
            status.textContent = 'No se pudo enviar ahora. Escríbenos a soporte@meddue.app.';
          }
        } finally {
          if (btn) {
            btn.disabled = false;
            btn.innerHTML = orig;
          }
        }
      });
    }
  }

  // --- 8. SUBPAGES (MODOS & ARQUITECTURA) 3D EXPERIENCE ---
  function initSubpageExperience(threeCtrl) {
    const modeBtns = $$('.mode-deep-tab-btn');
    const caregiverPanel = $('#panel-deep-caregiver');
    const petsPanel = $('#panel-deep-pets');
    const slotEl = $('.subpage-3d-slot');

    const syncSlotPos = (targetVec, fallbackX, fallbackY) => {
      if (!threeCtrl) return;
      if (window.innerWidth <= 960 || !slotEl) {
        targetVec.set(window.innerWidth <= 960 ? 0 : fallbackX, fallbackY, 0);
        return;
      }
      const r = slotEl.getBoundingClientRect();
      if (!r.width || !r.height) {
        targetVec.set(fallbackX, fallbackY, 0);
        return;
      }
      threeCtrl.camera.updateMatrixWorld();
      const cx = r.left + r.width * 0.5;
      const cy = r.top + r.height * 0.5;
      const ndc = new window.THREE.Vector2(
        (cx / window.innerWidth) * 2 - 1,
        -(cy / window.innerHeight) * 2 + 1
      );
      threeCtrl.raycaster.setFromCamera(ndc, threeCtrl.camera);
      threeCtrl.raycaster.ray.intersectPlane(threeCtrl.zPlane, targetVec);
    };

    const setHeroState = (shape, color, faceFront = true, rotSpeed = 0.22) => {
      if (!threeCtrl) return;
      const compact = window.innerWidth <= 960;
      const pos = new window.THREE.Vector3();
      syncSlotPos(pos, 2.05, 0.28);
      threeCtrl.state.isDigitizing = false;
      threeCtrl.state.phoneToPillMix = 1;
      threeCtrl.state.dissolveProgress = 1.35;
      threeCtrl.state.activeShape = shape;
      threeCtrl.state.targetColor.set(color);
      threeCtrl.state.faceFront = faceFront;
      threeCtrl.state.rotSpeed = rotSpeed;
      threeCtrl.state.particleOpacity = compact ? 0 : 0.88;
      threeCtrl.state.targetPos.copy(pos);
      threeCtrl.state.targetScale = compact ? 0.62 : 0.86;
      threeCtrl.masterGroup.position.copy(pos);
      threeCtrl.masterGroup.scale.setScalar(threeCtrl.state.targetScale);
      if (typeof threeCtrl.snapShape === 'function') threeCtrl.snapShape(shape);
    };

    // Modos page: interactive Caregiver (heart) <-> Pets (paw) switcher
    if (modeBtns.length && caregiverPanel && petsPanel) {
      let currentMode = 'caregiver';
      const applyMode = (mode) => {
        currentMode = mode === 'pets' ? 'pets' : 'caregiver';
        document.body.setAttribute('data-mode-theme', currentMode);
        modeBtns.forEach((b) => {
          const active = b.getAttribute('data-target-mode') === currentMode;
          b.classList.toggle('active', active);
          b.setAttribute('aria-selected', active ? 'true' : 'false');
        });
        caregiverPanel.hidden = currentMode !== 'caregiver';
        petsPanel.hidden = currentMode !== 'pets';

        if (threeCtrl) {
          threeCtrl.state.activeShape = currentMode === 'pets' ? 'paw' : 'heart';
          threeCtrl.state.targetColor.set(currentMode === 'pets' ? '#10b981' : '#a78bfa');
          threeCtrl.state.faceFront = true;
          threeCtrl.state.rotSpeed = 0.22;
        }
      };

      modeBtns.forEach((btn) => {
        btn.addEventListener('click', () => {
          const target = btn.getAttribute('data-target-mode');
          if (target) applyMode(target);
        });
      });

      if (threeCtrl && slotEl && !prefersReducedMotion) {
        const { camera, masterGroup, state } = threeCtrl;
        document.body.classList.add('has-mode-figure');
        setHeroState('heart', '#a78bfa', true, 0.22);
        state.currentColor.copy(state.targetColor);

        let frame = 0;
        const syncModeFigure = () => {
          frame = 0;
          const rect = slotEl.getBoundingClientRect();
          const centerX = rect.left + rect.width / 2;
          const compact = window.innerWidth <= 960;
          const centerY = rect.top + rect.height * (compact ? 0.5 : 0.42);
          const unit = 2 * Math.tan(camera.fov * Math.PI / 360) * camera.position.z / window.innerHeight;

          state.targetPos.set((centerX - window.innerWidth / 2) * unit,
            (window.innerHeight / 2 - centerY) * unit, 0);
          state.targetScale = Math.min(0.86, rect.width * unit * 0.90 / 4.15, rect.height * unit / 3.3);
          state.particleOpacity = 0.88 * window.THREE.MathUtils.smoothstep(centerY, 68, 168);
        };
        const queueModeFigure = () => {
          if (!frame) frame = requestAnimationFrame(syncModeFigure);
        };

        syncModeFigure();
        masterGroup.position.copy(state.targetPos);
        masterGroup.scale.setScalar(state.targetScale);
        window.addEventListener('scroll', queueModeFigure, { passive: true });
        window.addEventListener('resize', queueModeFigure, { passive: true });
        const observer = new ResizeObserver(queueModeFigure);
        observer.observe(slotEl.closest('.subpage-hero-grid'));
      }
      applyMode('caregiver');
      return;
    }

  }

  function initArchitectureExperience(threeCtrl) {
    const slots = $$('[data-architecture-model]');
    if (!threeCtrl || !slots.length || prefersReducedMotion) return;

    document.body.classList.add('has-architecture-models');
    const { camera, masterGroup, state } = threeCtrl;
    const { smoothstep } = window.THREE.MathUtils;
    let currentSlot = null;
    let frame = 0;

    state.isDigitizing = false;
    state.phoneToPillMix = 1;
    state.dissolveProgress = 1.35;
    state.faceFront = true;

    const sync = () => {
      frame = 0;
      const width = window.innerWidth;
      const height = window.innerHeight;
      const unit = 2 * Math.tan(camera.fov * Math.PI / 360) * camera.position.z / height;
      const focusY = height * 0.44;
      let selected;
      let bestScore = -Infinity;

      for (const slot of slots) {
        const bounds = slot.getBoundingClientRect();
        if (!bounds.height || !bounds.width) continue;
        const center = bounds.top + bounds.height / 2;
        const visible = Math.max(0, Math.min(bounds.bottom, height) - Math.max(bounds.top, HEADER_SCROLL_OFFSET));
        const score = visible / bounds.height - Math.abs(center - focusY) / height;
        if (score > bestScore) {
          bestScore = score;
          selected = { slot, bounds, center, visible };
        }
      }
      if (!selected) return;

      const { slot, bounds, center, visible } = selected;
      const centerX = bounds.left + bounds.width / 2;
      state.targetPos.set((centerX - width / 2) * unit, (height / 2 - center) * unit, 0);
      state.targetScale = Math.min(0.9, Math.min(bounds.width / 4.15, bounds.height / 3.45) * unit);
      state.particleOpacity = 0.9 * smoothstep(visible / bounds.height, 0.02, 0.55);

      if (currentSlot !== slot) {
        state.activeShape = slot.dataset.architectureModel;
        state.targetColor.set(slot.dataset.modelColor);
        if (!currentSlot) {
          threeCtrl.snapShape(state.activeShape);
          state.currentColor.copy(state.targetColor);
          masterGroup.position.copy(state.targetPos);
          masterGroup.scale.setScalar(state.targetScale);
        }
        currentSlot = slot;
      }
    };

    const queueSync = () => {
      if (!frame) frame = requestAnimationFrame(sync);
    };
    window.addEventListener('scroll', queueSync, { passive: true });
    window.addEventListener('resize', queueSync, { passive: true });
    window.addEventListener('hashchange', queueSync);
    window.addEventListener('pageshow', queueSync);
    const observer = new ResizeObserver(queueSync);
    observer.observe($('#main-content'));
    sync();
  }

  // --- BOOT ---
  document.addEventListener('DOMContentLoaded', () => {
    let lenisInstance = null;
    const getLenis = () => lenisInstance;

    initTheme();
    lenisInstance = initSmoothScroll();
    initNavigation(getLenis);

    const threeCtrl = initThreeScene();
    if ($('#hero')) {
      initHeroPhoneShowcase();
      initScrollytelling(threeCtrl, getLenis);
      initShowcase();
      initFaqAndForms();
    } else if (document.body.classList.contains('architecture-page')) {
      initArchitectureExperience(threeCtrl);
    } else {
      initSubpageExperience(threeCtrl);
    }

    if ('serviceWorker' in navigator && window.location.protocol.startsWith('http')) {
      navigator.serviceWorker.register('./sw.js').catch(() => {});
    }
  });
})();
