import { defineComponent } from '@/lib/component';
import './header.css';

defineComponent<HTMLElement>('[data-component="header"]', (el) => {
  const toggle = el.querySelector<HTMLButtonElement>('[data-header-toggle]');
  toggle?.addEventListener('click', () => {
    el.classList.toggle('is-open');
  });
});
