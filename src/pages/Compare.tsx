import Board from "../components/Board";
import Stats from "../components/Stats";
import Feed from "../components/Feed";

export default function ComparePage({ jobId, project }) {
  return (
    <div className="pt-6">
      <Stats jobId={jobId} />
      <div className="grid grid-cols-1 2xl:grid-cols-[minmax(0,1fr)_332px] gap-6 mt-6">
        <Board jobId={jobId} />
        <Feed projectId={project._id} limit={14} />
      </div>
    </div>
  );
}
