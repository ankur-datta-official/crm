import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function getEmailPrefix(email?: string | null) {
  if (!email) {
    return "";
  }

  return email.split("@")[0]?.trim() ?? "";
}

export function getDisplayName(fullName?: string | null, email?: string | null, fallback = "Unknown user") {
  if (fullName?.trim()) {
    return fullName.trim();
  }

  const emailPrefix = getEmailPrefix(email);
  if (emailPrefix) {
    return emailPrefix;
  }

  return fallback;
}

export function getInitials(fullName?: string | null, email?: string | null) {
  const source = getDisplayName(fullName, email, "User");
  const words = source
    .split(/[\s._-]+/)
    .map((part) => part.trim())
    .filter(Boolean);

  if (words.length === 0) {
    return "U";
  }

  if (words.length === 1) {
    return words[0].slice(0, 2).toUpperCase();
  }

  return `${words[0][0] ?? ""}${words[1][0] ?? ""}`.toUpperCase();
}
