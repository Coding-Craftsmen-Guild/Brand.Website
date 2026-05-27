type ElWithInit = Element & { __inited?: boolean };

export function defineComponent<E extends Element = HTMLElement>(
  selector: string,
  init: (el: E) => void | (() => void),
) {
  const apply = () => {
    document.querySelectorAll<E>(selector).forEach((el) => {
      const e = el as ElWithInit;
      if (e.__inited) return;
      e.__inited = true;
      init(el);
    });
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', apply);
  } else {
    apply();
  }
}
