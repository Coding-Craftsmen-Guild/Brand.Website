import './main.css';

import.meta.glob('../Views/**/*.scss', { eager: true });
import.meta.glob<{ default?: () => void }>('../Views/**/*.ts', { eager: true });
