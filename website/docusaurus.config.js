// @ts-check
const { themes } = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'OCS Inventory Docker',
  tagline: 'Production Docker stack for OCS Inventory 3.0',

  // Update these for your GitHub Pages deployment.
  url: 'https://vdeville.github.io',
  baseUrl: '/ocsinventory-docker/',
  organizationName: 'vdeville',
  projectName: 'ocsinventory-docker',
  trailingSlash: false,
  favicon: 'img/favicon.svg',

  onBrokenLinks: 'throw',

  i18n: { defaultLocale: 'en', locales: ['en'] },

  // .md files are parsed as CommonMark (lenient), .mdx as MDX.
  markdown: {
    format: 'detect',
    mermaid: true,
    hooks: { onBrokenMarkdownLinks: 'warn' },
  },

  themes: ['@docusaurus/theme-mermaid'],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          path: '../docs',
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl:
            'https://github.com/vdeville/ocsinventory-docker/edit/main/',
        },
        blog: false,
        theme: { customCss: require.resolve('./src/css/custom.css') },
        sitemap: { changefreq: 'weekly', priority: 0.5, filename: 'sitemap.xml' },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      metadata: [
        { name: 'keywords', content: 'OCS Inventory, Docker, docker compose, Django, Vue, PostgreSQL, self-hosted, IT asset management, inventory, GHCR' },
        { name: 'theme-color', content: '#2496ED' },
      ],
      navbar: {
        title: 'OCS Inventory Docker',
        items: [
          {
            href: 'https://github.com/vdeville/ocsinventory-docker',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              { label: 'Getting started', to: '/getting-started' },
              { label: 'Configuration', to: '/configuration' },
              { label: 'Architecture', to: '/architecture' },
            ],
          },
          {
            title: 'Operate',
            items: [
              { label: 'Operations', to: '/operations' },
              { label: 'Upgrading', to: '/operations/upgrading' },
              { label: 'Troubleshooting', to: '/operations/troubleshooting' },
            ],
          },
          {
            title: 'More',
            items: [
              { label: 'Developer docs', to: '/developer' },
              { label: 'GitHub', href: 'https://github.com/vdeville/ocsinventory-docker' },
              { label: 'OCS Inventory', href: 'https://ocsinventory-ng.org' },
            ],
          },
        ],
        copyright: `OCS Inventory Docker — built with Docusaurus.`,
      },
      prism: {
        theme: themes.github,
        darkTheme: themes.dracula,
        additionalLanguages: ['bash', 'yaml', 'json', 'docker', 'nginx'],
      },
    }),
};

module.exports = config;
