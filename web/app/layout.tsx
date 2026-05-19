import type { Metadata, Viewport } from "next";
import { Analytics } from '@vercel/analytics/next';
import "./globals.css";
import SiteJsonLd from "./components/site-json-ld";
import { getSiteUrl } from "../lib/site-url";

const siteUrl = getSiteUrl();

export const metadata: Metadata = {
  metadataBase: siteUrl,
  title: {
    default: "TelegramControl — Magisk module builder · ZIP Telegram bot",
    template: "%s · TelegramControl",
  },
  description:
    "Tạo ZIP module Magisk nhúng Bot Token và Chat ID (config.sh), flash trên Android để điều khiển máy qua Telegram. · Build a Magisk ZIP with embedded Telegram bot config for remote phone control.",
  applicationName: "TelegramControl",
  authors: [{ name: "Zakshin (Hải Nghĩa)" }],
  icons: {
    icon: [{ url: "/logo.png" }],
    apple: [{ url: "/logo.png" }],
  },
  keywords: [
    "Magisk",
    "Magisk module",
    "Telegram bot",
    "Android",
    "TelegramControl",
    "ZIP builder",
    "remote control",
    "điều khiển điện thoại",
    "module Magisk",
    "BotFather",
    "config.sh",
    "điện thoại Android",
  ],
  alternates: {
    canonical: "/",
    languages: {
      vi: "/",
      "x-default": "/",
      en: "/",
    },
  },
  openGraph: {
    type: "website",
    locale: "vi_VN",
    alternateLocale: ["en_US"],
    url: siteUrl,
    siteName: "TelegramControl",
    title: "TelegramControl — Magisk module builder",
    description:
      "Tải ZIP module Magisk đã nhúng Telegram bot · Download configured Magisk module for Android.",
    images: [
      {
        url: "/logo.png",
        width: 512,
        height: 512,
        alt: "TelegramControl",
      },
    ],
  },
  twitter: {
    card: "summary",
    title: "TelegramControl — Magisk module builder",
    description:
      "Magisk ZIP + Telegram bot config.sh · Module điều khiển Android qua Telegram.",
    images: ["/logo.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true },
  },
  appleWebApp: {
    capable: true,
    title: "TelegramControl",
    statusBarStyle: "black-translucent",
  },
  formatDetection: {
    telephone: false,
    email: false,
    address: false,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#0c0f14" },
    { media: "(prefers-color-scheme: light)", color: "#eef2f9" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="vi" suppressHydrationWarning data-theme="dark">
      <body>
        <SiteJsonLd />
        {children}
        <Analytics />
      </body>
    </html>
  );
}
