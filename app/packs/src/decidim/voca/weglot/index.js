import startWeglot from "./start_weglot";
import switcher from "./switcher";

document.addEventListener("DOMContentLoaded", () => {
  startWeglot()
    .then(switcher)
    .then(() => {
      console.log("Voca Weglot: loaded");
    })
    .catch((error) => {
      console.error("Voca Weglot: error", error);
    });
});
