export function logServerError(context: string, error: unknown, metadata?: Record<string, unknown>) {
  console.error(`[${context}]`, {
    metadata: metadata ?? null,
    error,
  });
}

export function getSafeErrorMessage(error: unknown, fallback: string) {
  const rawMessage =
    error instanceof Error ? error.message : typeof error === "string" ? error : "";
  const normalized = rawMessage.toLowerCase();

  if (!rawMessage) {
    return fallback;
  }

  if (normalized.includes("duplicate key") || normalized.includes("already exists")) {
    return "A record with the same details already exists.";
  }

  if (normalized.includes("permission denied") || normalized.includes("access denied")) {
    return "You do not have permission to perform this action.";
  }

  if (normalized.includes("not found")) {
    return "The requested record could not be found.";
  }

  if (normalized.includes("invalid") || normalized.includes("validation")) {
    return "Some information is invalid. Please review the form and try again.";
  }

  if (normalized.includes("network") || normalized.includes("fetch")) {
    return "A connection issue occurred. Please try again.";
  }

  if (normalized.includes("violates") || normalized.includes("foreign key")) {
    return "Some linked data is no longer available. Refresh the page and try again.";
  }

  return fallback;
}
