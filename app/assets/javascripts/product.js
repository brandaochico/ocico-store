// Variant price on the product page. The image gallery (thumbnails, zoom)
// moved to app/javascript/controllers/product_gallery_controller.js.
window.addEventListener('DOMContentLoaded', () => {
  const radios = document.querySelectorAll("[data-js='variant-radio']");

  if (radios.length > 0) {
    const selectedRadio = document.querySelector("[data-js='variant-radio'][checked='checked']");
    if (selectedRadio) updateVariantPrice(selectedRadio);
  }

  radios.forEach(radio => {
    radio.addEventListener('click', () => updateVariantPrice(radio));
  });

  function updateVariantPrice(variant) {
    const variantPrice = variant.dataset.jsPrice;
    if (variantPrice) {
      document.querySelector("[data-js='price']").innerHTML = variantPrice;
    }
  }
});
