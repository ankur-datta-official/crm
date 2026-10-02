"use client";

import { useEffect, useState, useTransition } from "react";
import { Camera, Loader2, Trash2, UserRound } from "lucide-react";
import { useRouter } from "next/navigation";
import { UserAvatar } from "@/components/shared/user-avatar";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { CurrentProfileSettings } from "@/lib/profile/profile-actions";
import {
  removeProfileAvatar,
  updateCurrentProfile,
  uploadProfileAvatar,
} from "@/lib/profile/profile-actions";

type ProfileSettingsFormProps = {
  profile: CurrentProfileSettings;
};

type ProfileFormValues = {
  fullName: string;
  phone: string;
  jobTitle: string;
  department: string;
};

const allowedFileTypes = ["image/jpeg", "image/png", "image/webp"];

export function ProfileSettingsForm({ profile }: ProfileSettingsFormProps) {
  const router = useRouter();
  const [saveMessage, setSaveMessage] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saveFieldErrors, setSaveFieldErrors] = useState<Record<string, string>>({});
  const [avatarMessage, setAvatarMessage] = useState<string | null>(null);
  const [avatarError, setAvatarError] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [avatarUrl, setAvatarUrl] = useState(profile.avatarUrl);
  const [formValues, setFormValues] = useState<ProfileFormValues>({
    fullName: profile.fullName ?? "",
    phone: profile.phone ?? "",
    jobTitle: profile.jobTitle ?? "",
    department: profile.department ?? "",
  });
  const [isSaving, startSaveTransition] = useTransition();
  const [isUploadingAvatar, startUploadTransition] = useTransition();
  const [isRemovingAvatar, startRemoveTransition] = useTransition();

  useEffect(() => () => {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }
  }, [previewUrl]);

  function clearAvatarSelection() {
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }

    setSelectedFile(null);
    setPreviewUrl(null);
  }

  function resetFeedback() {
    setSaveMessage(null);
    setSaveError(null);
    setSaveFieldErrors({});
  }

  function handleReset() {
    resetFeedback();
    setFormValues({
      fullName: profile.fullName ?? "",
      phone: profile.phone ?? "",
      jobTitle: profile.jobTitle ?? "",
      department: profile.department ?? "",
    });
  }

  function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    setAvatarMessage(null);
    setAvatarError(null);
    const nextFile = event.target.files?.[0] ?? null;

    if (!nextFile) {
      clearAvatarSelection();
      return;
    }

    if (!allowedFileTypes.includes(nextFile.type)) {
      clearAvatarSelection();
      setAvatarError("Please upload JPG, PNG, or WEBP image.");
      event.target.value = "";
      return;
    }

    if (nextFile.size > 2 * 1024 * 1024) {
      clearAvatarSelection();
      setAvatarError("Profile photo must be under 2MB.");
      event.target.value = "";
      return;
    }

    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }

    setSelectedFile(nextFile);
    setPreviewUrl(URL.createObjectURL(nextFile));
  }

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    resetFeedback();

    startSaveTransition(async () => {
      const result = await updateCurrentProfile(formValues);

      if (!result.ok) {
        setSaveError(result.error ?? "Unable to update your profile right now.");
        setSaveFieldErrors(result.fieldErrors ?? {});
        return;
      }

      setSaveMessage(result.message ?? "Profile updated successfully.");
      router.refresh();
    });
  }

  function handleAvatarUpload() {
    if (!selectedFile) {
      setAvatarError("Please choose an image to upload.");
      return;
    }

    setAvatarMessage(null);
    setAvatarError(null);

    startUploadTransition(async () => {
      const formData = new FormData();
      formData.append("file", selectedFile);
      const result = await uploadProfileAvatar(formData);

      if (!result.ok) {
        setAvatarError(result.error ?? "Upload failed. Please try again.");
        return;
      }

      setAvatarUrl(result.avatarUrl ?? null);
      clearAvatarSelection();
      setAvatarMessage(result.message ?? "Profile photo updated successfully.");
      router.refresh();
    });
  }

  function handleRemoveAvatar() {
    setAvatarMessage(null);
    setAvatarError(null);

    startRemoveTransition(async () => {
      const result = await removeProfileAvatar();

      if (!result.ok) {
        setAvatarError(result.error ?? "Unable to remove your profile photo right now.");
        return;
      }

      setAvatarUrl(null);
      clearAvatarSelection();
      setAvatarMessage(result.message ?? "Profile photo removed successfully.");
      router.refresh();
    });
  }

  const displayedAvatarUrl = previewUrl ?? avatarUrl;
  const roleLabel = profile.roleName ?? "No assigned role";

  return (
    <div className="grid gap-6 lg:grid-cols-[340px_minmax(0,1fr)]">
      <div className="space-y-6">
        <Card>
          <CardHeader className="items-center text-center">
            <UserAvatar
              imageUrl={displayedAvatarUrl}
              fullName={formValues.fullName}
              email={profile.email}
              className="size-24"
              initialsClassName="text-xl"
            />
            <div className="space-y-2">
              <CardTitle>{formValues.fullName || "Workspace user"}</CardTitle>
              <CardDescription>{profile.email}</CardDescription>
            </div>
            <div className="flex flex-wrap items-center justify-center gap-2">
              <Badge variant="secondary">{roleLabel}</Badge>
              <Badge variant={profile.isActive ? "success" : "warning"}>
                {profile.isActive ? "Active" : "Inactive"}
              </Badge>
            </div>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-slate-600">
            <ProfileMeta label="Workspace" value={profile.organizationName} />
            <ProfileMeta label="Designation" value={formValues.jobTitle || "Not set"} />
            <ProfileMeta label="Department" value={formValues.department || "Not set"} />
            <ProfileMeta label="Phone" value={formValues.phone || "Not set"} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Avatar Upload</CardTitle>
            <CardDescription>Upload a square-friendly JPG, PNG, or WEBP image under 2MB.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="profile-avatar">Profile Photo</Label>
              <Input
                id="profile-avatar"
                type="file"
                accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp"
                onChange={handleFileChange}
              />
            </div>
            {selectedFile ? (
              <p className="text-sm text-slate-500">
                Ready to upload: {selectedFile.name}
              </p>
            ) : null}
            {avatarError ? (
              <Alert variant="destructive">
                <AlertTitle>Avatar update failed</AlertTitle>
                <AlertDescription>{avatarError}</AlertDescription>
              </Alert>
            ) : null}
            {avatarMessage ? (
              <Alert>
                <AlertTitle>Avatar updated</AlertTitle>
                <AlertDescription>{avatarMessage}</AlertDescription>
              </Alert>
            ) : null}
            <div className="flex flex-wrap gap-3">
              <Button type="button" onClick={handleAvatarUpload} disabled={!selectedFile || isUploadingAvatar}>
                {isUploadingAvatar ? <Loader2 className="animate-spin" /> : <Camera />}
                {isUploadingAvatar ? "Uploading..." : "Upload Photo"}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={handleRemoveAvatar}
                disabled={(!avatarUrl && !previewUrl) || isRemovingAvatar}
              >
                {isRemovingAvatar ? <Loader2 className="animate-spin" /> : <Trash2 />}
                {isRemovingAvatar ? "Removing..." : "Remove Photo"}
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Account Information</CardTitle>
            <CardDescription>These details reflect your current workspace access.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-slate-600">
            <ProfileMeta label="Email" value={profile.email} />
            <ProfileMeta label="Role" value={roleLabel} />
            <ProfileMeta label="Workspace" value={profile.organizationName} />
            <ProfileMeta label="Account Status" value={profile.isActive ? "Active" : "Inactive"} />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Profile Edit Form</CardTitle>
          <CardDescription>Required fields are marked with *. Update your personal CRM profile and contact details here.</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid gap-5 md:grid-cols-2">
              <Field
                id="profile-full-name"
                label="Full Name"
                required
                value={formValues.fullName}
                onChange={(value) => setFormValues((current) => ({ ...current, fullName: value }))}
                error={saveFieldErrors.fullName}
              />
              <ReadOnlyField id="profile-email" label="Email" value={profile.email} />
              <Field
                id="profile-phone"
                label="Phone"
                value={formValues.phone}
                onChange={(value) => setFormValues((current) => ({ ...current, phone: value }))}
                error={saveFieldErrors.phone}
              />
              <Field
                id="profile-job-title"
                label="Designation"
                value={formValues.jobTitle}
                onChange={(value) => setFormValues((current) => ({ ...current, jobTitle: value }))}
                error={saveFieldErrors.jobTitle}
              />
              <Field
                id="profile-department"
                label="Department"
                value={formValues.department}
                onChange={(value) => setFormValues((current) => ({ ...current, department: value }))}
                error={saveFieldErrors.department}
              />
              <ReadOnlyField id="profile-workspace" label="Workspace" value={profile.organizationName} />
              <ReadOnlyField id="profile-role" label="Role" value={roleLabel} />
              <ReadOnlyField id="profile-status" label="Account Status" value={profile.isActive ? "Active" : "Inactive"} />
            </div>

            {saveError ? (
              <Alert variant="destructive">
                <AlertTitle>Profile update failed</AlertTitle>
                <AlertDescription>{saveError}</AlertDescription>
              </Alert>
            ) : null}

            {saveMessage ? (
              <Alert>
                <AlertTitle>Profile updated</AlertTitle>
                <AlertDescription>{saveMessage}</AlertDescription>
              </Alert>
            ) : null}

            <div className="flex flex-wrap justify-end gap-3 border-t border-slate-200 pt-4">
              <Button type="button" variant="outline" onClick={handleReset} disabled={isSaving}>
                Reset
              </Button>
              <Button type="submit" disabled={isSaving}>
                {isSaving ? <Loader2 className="animate-spin" /> : <UserRound />}
                {isSaving ? "Saving..." : "Save Profile"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}

function Field({
  id,
  label,
  value,
  onChange,
  error,
  required = false,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  error?: string;
  required?: boolean;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>
        {label}
        {required ? <span className="text-destructive"> *</span> : null}
      </Label>
      <Input id={id} value={value} onChange={(event) => onChange(event.target.value)} />
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
    </div>
  );
}

function ReadOnlyField({ id, label, value }: { id: string; label: string; value: string }) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <Input id={id} value={value} readOnly className="bg-slate-50 text-slate-600" />
    </div>
  );
}

function ProfileMeta({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50/70 px-3 py-2">
      <span className="text-slate-500">{label}</span>
      <span className="truncate text-right font-medium text-slate-900">{value}</span>
    </div>
  );
}
