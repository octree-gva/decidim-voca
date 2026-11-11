import startWeglot from "./start_weglot";
import switcher from "./switcher";
import { error, log } from "../debug";

document.addEventListener("DOMContentLoaded", () => {
  startWeglot()
    .then(switcher)
    .then(() => {
      log("Voca Weglot: loaded");
    })
    .catch((err) => {
      error("Voca Weglot: error", err);
    });
});
