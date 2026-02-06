import { Brain, Mic, Hand, Footprints, Smile, Activity, LucideIcon } from 'lucide-react';

interface CategoryIconProps {
  category: string;
  className?: string;
}

const iconMap: Record<string, LucideIcon> = {
  cognitive: Brain,
  speech: Mic,
  motor: Hand,
  gait: Footprints,
  facial: Smile,
  default: Activity,
};

export function CategoryIcon({ category, className = 'w-5 h-5' }: CategoryIconProps) {
  const IconComponent = iconMap[category?.toLowerCase()] || iconMap.default;
  return <IconComponent className={className} />;
}

export function getCategoryIconComponent(category: string): LucideIcon {
  return iconMap[category?.toLowerCase()] || iconMap.default;
}