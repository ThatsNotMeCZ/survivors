import { runCapture } from './capture-promo';

void runCapture(['itch', ...process.argv.slice(2)]).catch((err) => {
  console.error(err);
  process.exit(1);
});
