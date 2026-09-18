import Feed from "../components/Feed";

export default function ActivityPage({ projectId }) {
  return (
    <div className="pt-5 sm:pt-6 max-w-[760px]">
      <Feed projectId={projectId} limit={60} full />
    </div>
  );
}
