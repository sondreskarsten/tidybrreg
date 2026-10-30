// Typed conditions mirroring ?tidybrreg_conditions. Errors abort a tool
// call (reported as isError with the class and fields); warnings and
// messages are collected and returned with the result.

export interface Condition {
  kind: "warning" | "message";
  class: string;
  classes: string[];
  message: string;
  fields: Record<string, unknown>;
}

export class TidybrregError extends Error {
  readonly cls: string;
  readonly classes: string[];
  readonly fields: Record<string, unknown>;
  constructor(cls: string, message: string, fields: Record<string, unknown> = {}) {
    super(message);
    this.cls = `tidybrreg_error_${cls}`;
    this.classes = [this.cls, "tidybrreg_error", "error", "condition"];
    this.fields = fields;
  }
}

export class Conditions {
  readonly items: Condition[] = [];
  warn(cls: string, message: string, fields: Record<string, unknown> = {}): void {
    const full = `tidybrreg_warning_${cls}`;
    this.items.push({ kind: "warning", class: full, classes: [full, "tidybrreg_warning", "warning", "condition"], message, fields });
  }
  inform(message: string): void {
    this.items.push({ kind: "message", class: "message", classes: ["message", "condition"], message, fields: {} });
  }
}
