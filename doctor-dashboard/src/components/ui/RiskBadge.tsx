interface RiskBadgeProps {
  score: number;
  size?: 'sm' | 'md' | 'lg';
  showLabel?: boolean;
}

const getRiskConfig = (score: number) => {
  if (score >= 70) return { level: 'High', color: 'text-neuro-red', bg: 'bg-neuro-red/10', border: 'border-neuro-red/20' };
  if (score >= 40) return { level: 'Moderate', color: 'text-neuro-orange', bg: 'bg-neuro-orange/10', border: 'border-neuro-orange/20' };
  return { level: 'Low', color: 'text-neuro-green', bg: 'bg-neuro-green/10', border: 'border-neuro-green/20' };
};

const sizeStyles = {
  sm: 'text-xs px-2 py-0.5',
  md: 'text-sm px-3 py-1',
  lg: 'text-base px-4 py-1.5',
};

export function RiskBadge({ score, size = 'md', showLabel = true }: RiskBadgeProps) {
  const config = getRiskConfig(score);

  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full font-medium border
                 ${config.color} ${config.bg} ${config.border} ${sizeStyles[size]}`}
    >
      {showLabel && <span>{config.level}</span>}
      <span>{score}%</span>
    </span>
  );
}

interface RiskProgressProps {
  score: number;
  label?: string;
  showScore?: boolean;
}

export function RiskProgress({ score, label, showScore = true }: RiskProgressProps) {
  const config = getRiskConfig(score);
  
  const getGradient = () => {
    if (score >= 70) return 'from-neuro-orange to-neuro-red';
    if (score >= 40) return 'from-neuro-green to-neuro-orange';
    return 'from-neuro-green to-neuro-green';
  };

  return (
    <div className="w-full">
      {(label || showScore) && (
        <div className="flex items-center justify-between mb-2">
          {label && <span className="text-sm text-neuro-dark/60">{label}</span>}
          {showScore && <span className={`text-sm font-medium ${config.color}`}>{score}%</span>}
        </div>
      )}
      <div className="h-2 bg-neuro-dark/10 rounded-full overflow-hidden">
        <div
          className={`h-full rounded-full bg-gradient-to-r ${getGradient()} transition-all duration-500`}
          style={{ width: `${Math.min(score, 100)}%` }}
        />
      </div>
    </div>
  );
}
