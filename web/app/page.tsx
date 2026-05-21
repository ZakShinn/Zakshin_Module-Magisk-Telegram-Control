"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { moduleVersionLine } from "../lib/module-meta";
import { pick, type Lang } from "./strings";

const DONATE_STK = "0968884946";
const DONATE_VIETQR_URL =
  "https://img.vietqr.io/image/MB-0968884946-compact.png?addTag=ZakshinTools";
const DONATE_PAYPAL_URL = "https://paypal.me/Zakshin";
const CONTACT_FACEBOOK_URL =
  "https://www.facebook.com/profile.php?id=100006985387032";

const LS_THEME = "tg-module-theme";
const LS_LANG = "tg-module-lang";

type Theme = "dark" | "light";

export default function HomePage() {
  const [theme, setTheme] = useState<Theme>("dark");
  const [lang, setLang] = useState<Lang>("vi");
  const [mounted, setMounted] = useState(false);

  const [token, setToken] = useState("");
  const [chatId, setChatId] = useState("");
  const [hotspotSsid, setHotspotSsid] = useState("");
  const [hotspotPass, setHotspotPass] = useState("");
  const [hotspotPassVisible, setHotspotPassVisible] = useState(false);
  const [anydeskAutoMedia, setAnydeskAutoMedia] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const t = pick(lang);

  useEffect(() => {
    setMounted(true);
    try {
      const st = localStorage.getItem(LS_THEME) as Theme | null;
      const sl = localStorage.getItem(LS_LANG) as Lang | null;
      if (st === "light" || st === "dark") setTheme(st);
      if (sl === "en" || sl === "vi") setLang(sl);
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    if (!mounted) return;
    document.documentElement.setAttribute("data-theme", theme);
    try {
      localStorage.setItem(LS_THEME, theme);
    } catch {
      /* ignore */
    }
  }, [theme, mounted]);

  useEffect(() => {
    if (!mounted) return;
    document.documentElement.lang = lang === "vi" ? "vi" : "en";
    try {
      localStorage.setItem(LS_LANG, lang);
    } catch {
      /* ignore */
    }
  }, [lang, mounted]);

  async function downloadZip(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/module", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          lang,
          token: token.trim(),
          chatId: chatId.trim(),
          hotspotSsid: hotspotSsid.trim(),
          hotspotPass,
          anydeskAutoMedia,
        }),
      });
      if (!res.ok) {
        const j = await res.json().catch(() => ({}));
        const msg =
          lang === "vi"
            ? (typeof j.errorVi === "string" ? j.errorVi : null) ??
              (typeof j.error === "string" ? j.error : null)
            : (typeof j.errorEn === "string" ? j.errorEn : null) ??
              (typeof j.error === "string" ? j.error : null);
        setError(msg ?? `HTTP ${res.status}`);
        return;
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "TelegramControl.zip";
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      setError(t.errNetwork);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-shell">
      <a href="#main-content" className="skip-link">
        {t.skipToContent}
      </a>
      <header className="site-header">
        <a href="/" className="site-brand" aria-label={t.brandHomeAria}>
          <span className="brand-mark" aria-hidden="true">
            <Image
              className="brand-logo"
              src="/logo.png"
              alt=""
              width={44}
              height={44}
              priority
            />
          </span>
          <span className="brand-text">
            <span className="brand-name">{t.brandName}</span>
            <span className="brand-tagline">{t.siteKeywordsLine}</span>
          </span>
        </a>
        <nav className="masthead-nav" aria-label={t.mastheadNavAria}>
          <div className="segmented-pair">
            <div className="segmented" role="group" aria-label={t.themeGroupAria}>
              <span
                className="segmented-indicator"
                aria-hidden="true"
                data-pos={theme}
              />
              <button
                type="button"
                className={theme === "dark" ? "active" : ""}
                onClick={() => setTheme("dark")}
              >
                {t.themeDark}
              </button>
              <button
                type="button"
                className={theme === "light" ? "active" : ""}
                onClick={() => setTheme("light")}
              >
                {t.themeLight}
              </button>
            </div>
            <div className="segmented" role="group" aria-label={t.langGroupAria}>
              <span
                className="segmented-indicator"
                aria-hidden="true"
                data-pos={lang}
              />
              <button
                type="button"
                className={lang === "vi" ? "active" : ""}
                onClick={() => setLang("vi")}
              >
                {t.langVi}
              </button>
              <button
                type="button"
                className={lang === "en" ? "active" : ""}
                onClick={() => setLang("en")}
              >
                {t.langEn}
              </button>
            </div>
          </div>
        </nav>
      </header>

      <main id="main-content" className="main-content" tabIndex={-1}>
        <section className="hero" aria-labelledby="page-title">
          {t.heroEyebrow ? <p className="hero-eyebrow">{t.heroEyebrow}</p> : null}
          <h1 id="page-title">{t.title}</h1>
          <p className="hero-version" aria-label={moduleVersionLine(lang)}>
            {moduleVersionLine(lang)}
          </p>
        </section>

        <section className="builder-grid" aria-label={t.formSectionTitle}>
          <article className="card form-card" aria-labelledby="form-section-title">
            <h2 id="form-section-title" className="form-section-title">
              {t.formSectionTitle}
            </h2>

            <form onSubmit={downloadZip} aria-busy={loading}>
              <div className="field">
                <label htmlFor="chatId">{t.chatLabel}</label>
                <input
                  id="chatId"
                  name="chatId"
                  autoComplete="off"
                  placeholder={t.chatPh}
                  value={chatId}
                  onChange={(ev) => setChatId(ev.target.value)}
                  spellCheck={false}
                />
              </div>

              <div className="field">
                <label htmlFor="token">{t.tokenLabel}</label>
                <input
                  id="token"
                  name="token"
                  autoComplete="off"
                  placeholder="123456789:AA..."
                  value={token}
                  onChange={(ev) => setToken(ev.target.value)}
                  spellCheck={false}
                />
              </div>

              <fieldset className="hotspot-fieldset">
                <legend className="hotspot-legend">{t.hotspotFieldsetLegend}</legend>
                <div className="field">
                  <label htmlFor="hotspotSsid">{t.hotspotSsidLabel}</label>
                  <input
                    id="hotspotSsid"
                    name="hotspotSsid"
                    autoComplete="off"
                    placeholder={t.hotspotSsidPh}
                    value={hotspotSsid}
                    onChange={(ev) => setHotspotSsid(ev.target.value)}
                    spellCheck={false}
                    autoCapitalize="none"
                    autoCorrect="off"
                  />
                </div>
                <div className="field">
                  <label htmlFor="hotspotPass">{t.hotspotPassLabel}</label>
                  <div className="password-input-row">
                    <input
                      id="hotspotPass"
                      name="hotspotPass"
                      type={hotspotPassVisible ? "text" : "password"}
                      autoComplete="new-password"
                      placeholder={t.hotspotPassPh}
                      value={hotspotPass}
                      onChange={(ev) => setHotspotPass(ev.target.value)}
                      spellCheck={false}
                      autoCapitalize="none"
                      autoCorrect="off"
                    />
                    <button
                      type="button"
                      className="password-toggle"
                      onClick={() => setHotspotPassVisible((v) => !v)}
                      aria-pressed={hotspotPassVisible}
                      aria-label={
                        hotspotPassVisible ? t.hotspotPassHideAria : t.hotspotPassShowAria
                      }
                      aria-controls="hotspotPass"
                    >
                      {hotspotPassVisible ? t.hotspotPassHide : t.hotspotPassShow}
                    </button>
                  </div>
                </div>
                <p className="hotspot-hint">{t.hotspotHint}</p>
              </fieldset>

              <div className="field checkbox-field">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={anydeskAutoMedia}
                    onChange={(ev) => setAnydeskAutoMedia(ev.target.checked)}
                  />
                  <span>{t.anydeskAutoMediaLabel}</span>
                </label>
              </div>

              <button type="submit" disabled={loading}>
                {loading ? t.submitting : t.submit}
              </button>

              {error ? (
                <div className="err-block">
                  <div className="err" role="alert">
                    {error}
                  </div>
                  <p className="err-hint">
                    {t.errContactHint}{" "}
                    <a
                      href={CONTACT_FACEBOOK_URL}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {t.errContactLink}
                    </a>
                    .
                  </p>
                </div>
              ) : null}

              <div className="hint">{t.hint}</div>
              <p className="muted-note">{t.testedDevicesNote}</p>
            </form>
          </article>

          <aside className="card donate-card" aria-label={t.donateTitle}>
            <h2 className="donate-title">{t.donateTitle}</h2>
            <div className="donate-qr-wrap">
              <div className="donate-qr-stack">
                <div className="donate-qr-block">
                  <img
                    className="donate-qr"
                    src={DONATE_VIETQR_URL}
                    width={220}
                    height={220}
                    alt={t.donateQrAlt}
                    decoding="async"
                    loading="lazy"
                    fetchPriority="low"
                  />
                  <div className="donate-meta">
                    <div>
                      <strong>{t.donateRecipient}</strong>
                    </div>
                    <div className="bank">
                      {t.donateBankName} · {DONATE_STK}
                    </div>
                  </div>
                </div>

                <div className="donate-qr-block donate-paypal-hover-zone">
                  <div className="donate-qr-label">{t.donatePaypalLabel}</div>
                  <div className="donate-meta">
                    <div>
                      <a
                        className="donate-paypal-link"
                        href={DONATE_PAYPAL_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        paypal.me/Zakshin
                      </a>
                    </div>
                  </div>
                  <div className="donate-paypal-popover" aria-hidden="true">
                    <Image
                      className="donate-paypal-preview-img"
                      src="/Paypal.png"
                      alt=""
                      width={220}
                      height={220}
                      loading="lazy"
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="donate-logo-image-wrap" aria-hidden="true">
              <a
                href={CONTACT_FACEBOOK_URL}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={t.contactFacebook}
              >
                <Image
                  className="donate-logo-image"
                  src="/logo.png"
                  alt=""
                  width={220}
                  height={220}
                  loading="lazy"
                />
              </a>
            </div>

            <div className="links-row">
              <a
                href={CONTACT_FACEBOOK_URL}
                target="_blank"
                rel="noopener noreferrer"
              >
                {t.contactFacebook}
              </a>
            </div>
          </aside>
        </section>
      </main>
    </div>
  );
}
