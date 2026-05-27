import './main.css';

import.meta.glob<{ default?: () => void }>('../Views/**/*.ts', { eager: true });
