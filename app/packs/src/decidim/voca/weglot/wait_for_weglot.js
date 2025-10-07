export default async function waitForWeglot(retry = 0) {
  if (window.Weglot) {
    return;
  }
  if (retry > 10) {
    throw new Error("Voca Weglot: failed to load vendors");
  }
  await new Promise((resolve) => setTimeout(resolve, 1000));
  return waitForWeglot(retry + 1);
}
