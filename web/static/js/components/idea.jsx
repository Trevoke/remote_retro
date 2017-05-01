import React from "react"

import IdeaControls from "./idea_controls"
import IdeaEditForm from "./idea_edit_form"
import IdeaRestClient from "../clients/idea_rest_client"

import * as AppPropTypes from "../prop_types"
import styles from "./css_modules/idea.css"

function Idea(props) {
  const { idea, currentPresence, retroChannel } = props
  const isFacilitator = currentPresence.user.is_facilitator
  const isEdited = new Date(idea.updated_at) > new Date(idea.inserted_at)
  let classes = styles.index
  classes += idea.editing ? " ui raised segment" : ""

  const readOnlyIdea = (
    <div>
      { idea.editing && !isFacilitator ?
        <p className="ui center aligned sub dividing header">Facilitator is Editing</p> : ""
      }
      { isFacilitator &&
        <IdeaControls
          idea={idea}
          retroChannel={retroChannel}
          IdeaRestClient={IdeaRestClient}
        />
      }
      <span className={styles.authorAttribution}>
        {idea.author}:
      </span> {idea.liveEditText || idea.body}
      {isEdited && <span className={styles.editedIndicator}> (edited)</span>}
    </div>
  )

  return (
    <li className={classes} title={idea.body} key={idea.id}>
      { idea.editing && isFacilitator ?
        <IdeaEditForm idea={idea} retroChannel={retroChannel} IdeaRestClient={IdeaRestClient} />
        : readOnlyIdea
      }
    </li>
  )
}

Idea.propTypes = {
  idea: AppPropTypes.idea.isRequired,
  retroChannel: AppPropTypes.retroChannel.isRequired,
  currentPresence: AppPropTypes.presence.isRequired,
}

export default Idea
