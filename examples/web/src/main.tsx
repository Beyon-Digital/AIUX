import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "@beyond-digital/aiux-web/styles.css";
import "./app.css";
import App from "./App.jsx";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
