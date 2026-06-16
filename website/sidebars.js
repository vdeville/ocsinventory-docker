// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    'getting-started',
    {
      type: 'category',
      label: 'Configuration',
      link: { type: 'doc', id: 'configuration/README' },
      items: [
        'configuration/environment-variables',
        'configuration/base-paths',
        'configuration/tls-and-networking',
        'configuration/django-overlay',
      ],
    },
    'architecture',
    {
      type: 'category',
      label: 'Operations',
      link: {
        type: 'generated-index',
        slug: '/operations',
        title: 'Operations',
        description:
          'Run the OCS Inventory Docker stack in production: upgrades, admin & auth, agents, backups, logs, and troubleshooting.',
      },
      items: [
        'operations/upgrading',
        'operations/admin-auth-agents',
        'operations/backups-logs',
        'operations/troubleshooting',
      ],
    },
    {
      type: 'category',
      label: 'Developer docs',
      link: {
        type: 'generated-index',
        slug: '/developer',
        title: 'Developer docs',
        description:
          'Contribute to and build the OCS Inventory Docker images: project layout, source patches, releasing, and CI workflows.',
      },
      items: [
        'developer/layout',
        'developer/patches',
        'developer/releasing',
        'developer/workflows',
      ],
    },
  ],
};

module.exports = sidebars;
