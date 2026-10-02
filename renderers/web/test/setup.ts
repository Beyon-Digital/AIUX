import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// globals are off — register DOM cleanup per test explicitly.
afterEach(cleanup);
